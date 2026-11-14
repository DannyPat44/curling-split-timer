# Command-line builds: make run (simulator), make install (USB watch), make package (store)
SDK := $(shell cat "$(HOME)/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg" 2>/dev/null)
JAVA_HOME ?= /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export JAVA_HOME
DEVICE ?= fr265
# Your developer key: KEY=path/to/developer_key.der, set here, on the
# command line, or in local.mk (not committed)
-include local.mk
KEY ?= developer_key.der
APP := Curling

.PHONY: build run install package test icon sim-tools fit

build:
	"$(SDK)bin/monkeyc" -f monkey.jungle -d $(DEVICE) -y "$(KEY)" -o bin/$(APP).prg -w

SIMULATOR = @pgrep -qf ConnectIQ.app || { "$(SDK)bin/connectiq"; until pgrep -qf ConnectIQ.app; do sleep 1; done; sleep 2; }

run: build
	$(SIMULATOR)
	"$(SDK)bin/monkeydo" bin/$(APP).prg $(DEVICE)

# Unit tests (test/) run in the simulator; add TEST=name for one test.
# recordingSavesEveryGameField saves a real activity, and its file is then
# checked for every game field (tools/check_test_activity.py).
ACTIVITIES = $${TMPDIR}com.garmin.connectiq/GARMIN/Activities
test: bin/venv
	"$(SDK)bin/monkeyc" -f monkey.jungle -d $(DEVICE) -y "$(KEY)" -o bin/$(APP)Test.prg -w -t
	$(SIMULATOR)
	@touch bin/test-started
	@# monkeydo exits non-zero even when every test passes, so judge by its report
	@"$(SDK)bin/monkeydo" bin/$(APP)Test.prg $(DEVICE) -t $(TEST) | tee bin/test.log; grep -q "^PASSED" bin/test.log
	@if [ -z "$(TEST)" ] || [ "$(TEST)" = recordingSavesEveryGameField ]; then \
		fit=$$(find "$(ACTIVITIES)" -name '*.fit' -newer bin/test-started 2>/dev/null | sort | tail -1); \
		test -n "$$fit" || { echo "recordingSavesEveryGameField saved no activity"; exit 1; }; \
		bin/venv/bin/python -I tools/check_test_activity.py "$$fit"; \
	fi

# Copy onto a USB-connected watch over MTP (brew install libmtp)
install: build
	@apps=$$(mtp-folders 2>/dev/null | awk '$$2 == "GARMIN" {g=1} g && $$2 == "Apps" {print $$1; exit}'); \
	test -n "$$apps" || { echo "Watch not found: plug it in and close Garmin Express/OpenMTP"; exit 1; }; \
	mtp-sendfile bin/$(APP).prg $$apps > /dev/null && echo "Installed $(APP).prg; unplug the watch"

package:
	"$(SDK)bin/monkeyc" -f monkey.jungle -e -r -y "$(KEY)" -o bin/$(APP).iq

# Redraw the launcher icon: a flat side-view curling rock
icon:
	swift tools/rock_icon.swift resources/drawables/launcher_icon.png 60

# Screen checks: press the simulator's buttons and capture the watch (see
# tools/screens.sh). Needs Accessibility and Screen Recording for the terminal.
sim-tools: bin/sim

bin/sim: tools/sim.swift
	@mkdir -p bin
	swiftc -O tools/sim.swift -o bin/sim

# The app's lap and summary fields in an activity: the simulator's newest
# game, or FIT=file (one copied off the watch)
FIT ?= $(shell ls -t "$${TMPDIR}com.garmin.connectiq/GARMIN/Activities/"*.fit 2>/dev/null | head -1)
fit: bin/venv
	bin/venv/bin/python -I tools/fit_summary.py "$(FIT)"

bin/venv:
	python3 -m venv bin/venv && bin/venv/bin/pip -q install fitparse
