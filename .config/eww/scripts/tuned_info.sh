#!/bin/bash

profile=$(cat /etc/tuned/active_profile 2>/dev/null || echo "unknown")

case "$profile" in
  *)                        icon="󰘚" ;;
esac

case "$profile" in
  "accelerator-performance")    icon="" ;;
  "aws")                        icon="" ;;
  "balanced")                   icon="󰾅" ;;
  "balanced-battery")           icon="󰾆" ;;
  "cpu-partitioning")           icon="" ;;
  "cpu-partitioning-powersave") icon="" ;;
  "desktop")                    icon="󰍹" ;;
  "hpc-compute")                icon="" ;;
  "intel-sst")                  icon="" ;;
  "latency-performance")        icon="" ;;
  "mssql")                      icon="" ;;
  "network-latency")            icon="" ;;
  "network-throughput")         icon="" ;;
  "optimize-serial-console")    icon="" ;;
  "powersave")                  icon="󰌪" ;;
  "throughput-performance")     icon="󰓅" ;;
  "virtual-guest")              icon="" ;;
  "virtual-host")               icon="" ;;
  *)                            icon="unknown tuned profile!󰘚" ;;
esac

echo "{\"profile\": \"$profile\", \"icon\": \"$icon\"}"
