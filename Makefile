all: volume

volume:
	docker build -t blockbridge/volume-driver .

nocache:
	docker build --no-cache -t blockbridge/volume-driver .
