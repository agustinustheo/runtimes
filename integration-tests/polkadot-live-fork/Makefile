.PHONY: setup preflight config bite spawn verify-fork verify stop

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

stop:
	./scripts/stop.sh
