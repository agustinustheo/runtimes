.PHONY: build-wasm setup preflight config bite spawn verify-fork verify mark-runtime-logs upgrade verify-upgrade inspect-runtime-logs stop

build-wasm:
	./scripts/build-wasm.sh

setup:
	./scripts/setup.sh

preflight:
	@bash -c 'source ./scripts/common.sh && node ./scripts/preflight.mjs'

config:
	@bash -c 'source ./scripts/common.sh && node ./scripts/generate-config.mjs'

bite:
	./scripts/bite.sh

spawn:
	./scripts/spawn.sh

verify-fork:
	@bash -c 'source ./scripts/common.sh && node ./scripts/verify-fork.mjs'

verify:
	@bash -c 'source ./scripts/common.sh && node ./scripts/verify.mjs'

mark-runtime-logs:
	./scripts/runtime-logs.sh mark

upgrade:
	./scripts/upgrade.sh

verify-upgrade:
	@bash -c 'source ./scripts/common.sh && node ./scripts/verify-upgrade.mjs'

inspect-runtime-logs:
	./scripts/runtime-logs.sh inspect

stop:
	./scripts/stop.sh
