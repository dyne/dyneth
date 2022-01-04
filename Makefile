HOME ?= $(shell pwd)

include config.mk

export

all:
	@echo "Dyneth ${VERSION}" && echo
	@echo "Server commands:" ;\
	 echo " make run - start the API node listening on HTTP port ${API_PORT}" ;\
	 echo " make shell - open a shell inside running server (CMD=sh or custom)" ;\
	 echo " make status - see if server is running and print public address" ;\
	 echo " make stop - stop running server" ;\
	 echo
	@echo "Account commands:" ;\
	 echo " make account - create a new private account in ~/.dyneth/keystore" ;\
	 echo " make backup  - prints the private account contents as JSON string" ;\
	 echo " make restore - asks for private account string to restore from backup" ;\
	 echo " make run-signer - start the SIGNER node with current account" ;\
	 echo
	@echo "Development commands:" ;\
	 echo " make debug - run an interactive shell inside the node" ;\
	 echo " make build - build the local ./Dockerfile as dyne/dyneth:latest" ;\
	 echo

container := $(shell docker container ls | awk '/dyne\/dyneth/ { print $$1 }')

init:
	@sh ./scripts/motd

stopped:
	@if [ ! "x${container}" = "x" ]; then \
		echo "Already running in docker container: ${container}"; echo; exit 1; fi

running:
	@if [ "x${container}" = "x" ]; then \
		echo "Container is not running"; echo; exit 1; fi

build:
	make -C devops

build-release:
	VERSION=${VERSION} make -C devops

run:	init stopped
run:
	@echo "Launching docker container for the HTTP API service:"
	docker run --restart unless-stopped -d \
	 -p ${P2P_PORT}:${P2P_PORT}/tcp \
	 -p ${P2P_PORT}:${P2P_PORT}/udp -p ${API_PORT}:${API_PORT} \
	 dyne/dyneth sh /start-geth-api.sh
	@echo "P2P networking through port 30303"
	@echo "HTTP API available at port 8545"
	@echo "run 'make shell' for an interactive console" && echo

console: init running
console:
	echo "Console starting" && echo
	docker exec -it ${container} geth attach /var/lib/dyneth/geth.ipc

stop:	init running
stop:
	@echo "Stopping container: ${container}"
	docker container stop ${container}

shell:	init running
shell:	CMD ?= "sh"
shell:
	@echo "Container running: ${container}"
	@echo "Executing command: ${CMD}" && echo
	docker exec -it ${container} ${CMD}
	@echo && echo "Command executed: ${CMD}" && echo


# SIGNER

run-signer: init stopped
run-signer:
	@echo "Launching docker container for the SIGNING service:"
	docker run -it \
	--mount type=bind,source=${DATA},destination=/var/lib/dyneth \
	 -p ${P2P_PORT}:${P2P_PORT}/tcp -p ${P2P_PORT}:${P2P_PORT}/udp \
	 dyne/dyneth sh /start-geth-signer.sh
	@echo "P2P networking through port ${P2P_PORT}"
	@echo "run 'make shell' for an interactive console" && echo

account: init
	@bash ./scripts/account.sh new

backup: init
	@bash ./scripts/account.sh backup

restore: init
	@bash ./scripts/account.sh restore

status: init
status:
	@if [ "x${container}" = "x" ]; then \
		echo "Status: NOT RUNNING" && echo ;\
	else \
		echo "Status: RUNNING" && echo ;\
	fi


# DEBUG

debug:	init stopped
debug:
	@echo "P2P networking through port ${P2P_PORT}"
	@echo "HTTP API available at port ${API_PORT}"
	@echo "Data storage in ~/.dyneth" && echo
	@echo "Debugging docker container:"
	docker run -it -p ${P2P_PORT}:${P2P_PORT}/tcp \
	 -p ${P2P_PORT}:${P2P_PORT}/udp -p ${API_PORT}:${API_PORT} \
	 --mount type=bind,source=${DATA},destination=/var/lib/dyneth \
	 dyne/dyneth sh
