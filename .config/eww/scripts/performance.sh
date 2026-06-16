#!/usr/bin/env bash
#
# performance.sh -- emit a single JSON blob with CPU / GPU / memory stats
# consumed by the `performance` eww window (perf_json poll).
#
# Portable across machines:
#   * CPU model name from /proc/cpuinfo
#   * GPU model name(s) from lspci (and nvidia-smi when available)
#   * GPU usage/freq/vram per driver:  xe (Intel), amdgpu (AMD), nvidia
#   * Emits a "gpus" array so multi-GPU systems (e.g. Ryzen iGPU + NVIDIA
#     dGPU) show every card. Falls back gracefully to 0 / "n/a".

set -uo pipefail

# ---- small helpers -------------------------------------------------------
cat_q()    { cat "$1" 2>/dev/null; }
json_str() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# integer percentage (handles div-by-zero -> 0, clamps 0..100)
pct() { awk -v a="$1" -v b="$2" 'BEGIN{ if (b+0==0) print 0; else { v=100*a/b; if(v<0)v=0; if(v>100)v=100; printf "%d", v+0.5 } }'; }

# ---- CPU model name ------------------------------------------------------
cpu_name=$(grep -m1 'model name' /proc/cpuinfo \
  | sed -E 's/.*model name[[:space:]]*:[[:space:]]*//; s/\(R\)//g; s/\(TM\)//g; s/ CPU.*//; s/ w\/.*//; s/[[:space:]]+/ /g; s/^ //; s/ $//')
cpu_name=${cpu_name:-Unknown CPU}

# =========================================================================
# Discover GPUs: every base DRM card (card0, card1, ...) + its driver + PCI
# =========================================================================
gpu_cards=(); gpu_drivers=(); gpu_addrs=()
for c in /sys/class/drm/card[0-9]*; do
  base=$(basename "$c")
  [[ "$base" =~ ^card[0-9]+$ ]] || continue        # skip connectors (card0-DP-1)
  dev="$c/device"
  drv=$(basename "$(readlink -f "$dev/driver" 2>/dev/null)" 2>/dev/null)
  addr=$(basename "$(readlink -f "$dev" 2>/dev/null)")   # e.g. 0000:00:02.0
  gpu_cards+=("$c"); gpu_drivers+=("${drv:-unknown}"); gpu_addrs+=("$addr")
done

# GPU model name via lspci (prefer the bracketed marketing name)
gpu_name_for() {
  local addr="$1" short dev
  short="${addr#0000:}"                              # 0000:00:02.0 -> 00:02.0
  dev=$(lspci -mm -s "$short" 2>/dev/null | awk -F'"' '{print $6}')
  [ -z "$dev" ] && { echo "GPU"; return; }
  if echo "$dev" | grep -q '\['; then
    dev=$(echo "$dev" | sed -E 's/.*\[([^][]*)\][^][]*$/\1/')   # last [...]
  fi
  echo "$dev" | sed -E 's/^ +//; s/ +$//'
}

# =========================================================================
# Sampling: CPU% and Intel(xe) GPU% need a delta -> sample, sleep, sample.
# =========================================================================
read -r _ c_u c_n c_s c_i c_io c_irq c_si c_st _ < /proc/stat
cpu1_idle=$(( c_i + c_io ))
cpu1_total=$(( c_u + c_n + c_s + c_i + c_io + c_irq + c_si + c_st ))

declare -A xe_idle1 xe_wall1
for idx in "${!gpu_cards[@]}"; do
  [ "${gpu_drivers[$idx]}" = "xe" ] || continue
  v=$(cat_q "${gpu_cards[$idx]}/device/tile0/gt0/gtidle/idle_residency_ms"); xe_idle1[$idx]=${v:-0}
  read -r up _ < /proc/uptime; xe_wall1[$idx]=$(awk -v u="$up" 'BEGIN{printf "%d", u*1000}')
done

sleep 0.5

read -r _ c_u c_n c_s c_i c_io c_irq c_si c_st _ < /proc/stat
cpu2_idle=$(( c_i + c_io ))
cpu2_total=$(( c_u + c_n + c_s + c_i + c_io + c_irq + c_si + c_st ))

d_total=$(( cpu2_total - cpu1_total ))
d_idle=$(( cpu2_idle - cpu1_idle ))
cpu_perc=$(pct $(( d_total - d_idle )) "$d_total")

# =========================================================================
# Per-GPU stats -> build the "gpus" JSON array
# =========================================================================
build_xe() {                 # $1=card idx ; sets perc/freq/freq_max/vu/vt/shared
  local card="${gpu_cards[$1]}"
  local i2 up2 w2 didle dwall
  i2=$(cat_q "$card/device/tile0/gt0/gtidle/idle_residency_ms"); i2=${i2:-0}
  read -r up2 _ < /proc/uptime; w2=$(awk -v u="$up2" 'BEGIN{printf "%d", u*1000}')
  didle=$(( i2 - ${xe_idle1[$1]:-0} )); dwall=$(( w2 - ${xe_wall1[$1]:-0} ))
  if (( dwall > 0 )); then
    perc=$(awk -v idle="$didle" -v wall="$dwall" 'BEGIN{ v=100-(100*idle/wall); if(v<0)v=0; if(v>100)v=100; printf "%d", v+0.5 }')
  else perc=0; fi
  # act_freq reads 0 when the GPU is power-gated/idle -> fall back to cur_freq
  freq=$(cat_q "$card/device/tile0/gt0/freq0/act_freq");  freq=${freq:-0}
  if [ "${freq:-0}" -eq 0 ] 2>/dev/null; then
    freq=$(cat_q "$card/device/tile0/gt0/freq0/cur_freq"); freq=${freq:-0}
  fi
  freq_max=$(cat_q "$card/device/tile0/gt0/freq0/max_freq"); freq_max=${freq_max:-0}
  # iGPU shares system RAM: sum resident mem across xe drm clients
  local bytes=0 v
  for fdi in /proc/[0-9]*/fdinfo/*; do
    [ -r "$fdi" ] || continue
    grep -q '^drm-driver:.*xe' "$fdi" 2>/dev/null || continue
    while IFS= read -r v; do bytes=$(( bytes + v )); done < <(
      grep -E '^drm-resident-(gtt|stolen|system):' "$fdi" 2>/dev/null | grep -oE '[0-9]+')
  done
  vu=$(( bytes / 1024 / 1024 ))
  vt=$(( $(awk '/^MemTotal:/{print $2}' /proc/meminfo) / 1024 ))
  temp=$(gpu_temp_card "$card")   # Lunar Lake exposes none -> 0
  shared=true
}

# GPU temperature (°C) from the card's hwmon, 0 if no sensor exists.
# Prefers a representative sensor (edge/junction/GPU), else the first temp.
gpu_temp_card() {            # $1=card path
  local card="$1" hw lf t r
  for hw in "$card/device/hwmon"/hwmon*; do
    [ -d "$hw" ] || continue
    for lf in "$hw"/temp*_label; do
      [ -f "$lf" ] || continue
      case "$(cat_q "$lf")" in
        edge|junction|GPU*|Package*)
          r=$(cat_q "${lf%_label}_input"); [ -n "$r" ] && { echo $(( r / 1000 )); return; } ;;
      esac
    done
    for t in "$hw"/temp*_input; do
      [ -f "$t" ] && { r=$(cat_q "$t"); [ -n "$r" ] && { echo $(( r / 1000 )); return; }; }
    done
  done
  echo 0
}

build_amdgpu() {             # $1=card idx
  local card="${gpu_cards[$1]}" d="${gpu_cards[$1]}/device" raw f
  perc=$(cat_q "$d/gpu_busy_percent"); perc=${perc:-0}
  f="$d/pp_dpm_sclk"
  freq=$(grep '\*' "$f" 2>/dev/null | grep -oE '[0-9]+' | head -1); freq=${freq:-0}
  freq_max=$(tail -n1 "$f" 2>/dev/null | grep -oE '[0-9]+' | head -1); freq_max=${freq_max:-0}
  raw=$(cat_q "$d/mem_info_vram_used");  vu=$(( ${raw:-0} / 1024 / 1024 ))
  raw=$(cat_q "$d/mem_info_vram_total"); vt=$(( ${raw:-0} / 1024 / 1024 ))
  temp=$(gpu_temp_card "$card")
  shared=false
}

build_nvidia() {             # $1=card idx ; uses nvidia-smi matched by PCI bus
  local short="${gpu_addrs[$1]#0000:}" line
  perc=0; freq=0; freq_max=0; vu=0; vt=0; temp=0; shared=false
  command -v nvidia-smi >/dev/null 2>&1 || return
  line=$(nvidia-smi --query-gpu=pci.bus_id,utilization.gpu,clocks.gr,clocks.max.gr,memory.used,memory.total,temperature.gpu \
           --format=csv,noheader,nounits 2>/dev/null | grep -i "$short")
  [ -z "$line" ] && return
  IFS=',' read -r _ perc freq freq_max vu vt temp <<< "$line"
  perc=$(echo "$perc" | tr -dc '0-9'); freq=$(echo "$freq" | tr -dc '0-9')
  freq_max=$(echo "$freq_max" | tr -dc '0-9'); vu=$(echo "$vu" | tr -dc '0-9')
  vt=$(echo "$vt" | tr -dc '0-9'); temp=$(echo "$temp" | tr -dc '0-9')
  perc=${perc:-0}; freq=${freq:-0}; freq_max=${freq_max:-0}; vu=${vu:-0}; vt=${vt:-0}; temp=${temp:-0}
}

gpu_objs=()
for idx in "${!gpu_cards[@]}"; do
  perc=0; freq=0; freq_max=0; vu=0; vt=0; temp=0; shared=false
  case "${gpu_drivers[$idx]}" in
    xe)        build_xe "$idx" ;;
    amdgpu)    build_amdgpu "$idx" ;;
    nvidia)    build_nvidia "$idx" ;;
  esac
  name=$(gpu_name_for "${gpu_addrs[$idx]}")
  # nvidia-smi usually has a cleaner marketing name
  if [ "${gpu_drivers[$idx]}" = "nvidia" ] && command -v nvidia-smi >/dev/null 2>&1; then
    nv=$(nvidia-smi --query-gpu=pci.bus_id,name --format=csv,noheader 2>/dev/null \
           | grep -i "${gpu_addrs[$idx]#0000:}" | cut -d',' -f2- | sed -E 's/^ +//; s/ +$//')
    [ -n "$nv" ] && name="$nv"
  fi
  vperc=$(pct "$vu" "$vt")
  gpu_objs+=("{\"name\":\"$(json_str "$name")\",\"driver\":\"${gpu_drivers[$idx]}\",\"perc\":$perc,\"freq\":$freq,\"freq_max\":$freq_max,\"temp\":${temp:-0},\"vram_used\":$vu,\"vram_total\":$vt,\"vram_perc\":$vperc,\"shared\":$shared}")
done
gpus_json="[$(IFS=,; echo "${gpu_objs[*]}")]"

# =========================================================================
# CPU point-in-time stats
# =========================================================================
cores=$(nproc 2>/dev/null || echo 1)
freq_sum=0; freq_n=0
for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq; do
  v=$(cat_q "$f"); [ -n "$v" ] && { freq_sum=$(( freq_sum + v )); freq_n=$(( freq_n + 1 )); }
done
if (( freq_n > 0 )); then cpu_freq=$(( freq_sum / freq_n / 1000 )); else cpu_freq=0; fi
cmaxraw=$(cat_q /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)
cpu_freq_max=$(( ${cmaxraw:-0} / 1000 ))

cpu_temp=0
for h in /sys/class/hwmon/hwmon*; do
  name=$(cat_q "$h/name")
  [ "$name" = "coretemp" ] || [ "$name" = "k10temp" ] || [ "$name" = "zenpower" ] || continue
  for lf in "$h"/temp*_label; do
    [ -f "$lf" ] || continue
    case "$(cat_q "$lf")" in
      "Package id 0"|"Tctl"|"Tdie")
        raw=$(cat_q "${lf%_label}_input"); cpu_temp=$(( ${raw:-0} / 1000 )); break ;;
    esac
  done
  [ "$cpu_temp" != 0 ] && break
done
# fallback: first coretemp/k10temp input if no labelled package sensor
if [ "$cpu_temp" = 0 ]; then
  for h in /sys/class/hwmon/hwmon*; do
    name=$(cat_q "$h/name")
    case "$name" in coretemp|k10temp|zenpower)
      raw=$(cat_q "$h/temp1_input"); [ -n "$raw" ] && { cpu_temp=$(( raw / 1000 )); break; } ;;
    esac
  done
fi

read -r load1 _ < /proc/loadavg

# ---- Swap / Disk / Uptime ----
swap_total=$(awk '/^SwapTotal:/{print int($2/1024)}' /proc/meminfo); swap_total=${swap_total:-0}
swap_free=$(awk '/^SwapFree:/{print int($2/1024)}' /proc/meminfo);  swap_free=${swap_free:-0}
swap_used=$(( swap_total - swap_free ))
swap_perc=$(pct "$swap_used" "$swap_total")

read -r disk_perc disk_used disk_total < <(
  df -h --output=pcent,used,size / 2>/dev/null | tail -n1 | tr -d '%' | awk '{print $1, $2, $3}')
disk_perc=${disk_perc:-0}; disk_used=${disk_used:-?}; disk_total=${disk_total:-?}

upt=$(awk '{s=int($1); d=int(s/86400); h=int((s%86400)/3600); m=int((s%3600)/60);
           if(d>0) printf "%dd %dh", d, h; else if(h>0) printf "%dh %dm", h, m; else printf "%dm", m}' /proc/uptime)

# =========================================================================
cat <<EOF
{"cpu_name":"$(json_str "$cpu_name")","cpu_perc":$cpu_perc,"cpu_freq":$cpu_freq,"cpu_freq_max":$cpu_freq_max,"cpu_temp":$cpu_temp,"cpu_cores":$cores,"load":"$load1","gpus":$gpus_json,"swap_used":$swap_used,"swap_total":$swap_total,"swap_perc":$swap_perc,"disk_perc":$disk_perc,"disk_used":"$disk_used","disk_total":"$disk_total","uptime":"$upt"}
EOF
