#!/bin/sh

# BLANK = "#00000000"
# CLEAR = '#ffffff22'
# DEFAULT = '#00897bE6'
# TEXT = '#00897bE6'
# WRONG = '#80000bb'
# VERIFYING = '#00564dE6'

i3lock \
	--insidever-color=#ffffff22 \
	--ringver-color=#00564dE6 \
	\
	--inside-color=#00000000 \
	--ring-color=#00897bE6 \
	--line-color=#00000000 \
	--separator-color=#00897bE6 \
	\
	--verif-color=#00897bE6 \
	--wrong-color=#00897bE6 \
	--time-color=#00897bE6 \
	--date-color=#00897bE6 \
	--layout-color=#00897bE6 \
	--keyhl-color=#800000bb \
	--bshl-color=#800000bb \
	\
	--screen 1 \
	--blur 9 \
	--clock \
#	--indicator \
	--time-str = "%H:%M:%S" \
	--date-str = "%A, %Y-%m-%d" \
	--keylayout 1 \
