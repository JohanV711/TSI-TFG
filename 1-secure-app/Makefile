up:
	chmod +x db/01_init.sh
	sudo docker compose up --build -d

down:
	sudo docker compose down

destroy:
	sudo docker compose down
	#Eliminar volúmenes, redes, imágenes todo.

stop:
	sudo docker compose stop

reset:
	sudo docker compose down -v

logs: 
	sudo docker compose logs -f
