# Vars
stack_name=plex

.PHONY: deploy
deploy:
	docker stack deploy $(stack_name) --compose-file docker-compose.yml

.PHONY: undeploy
undeploy:
	docker stack rm $(stack_name)

.PHONY: restart
restart:
	make undeploy
	make deploy

.PHONY: create-subdir
create-subdir:
	touch ./filebrowser/database.db
	mkdir medias/complete/books
	mkdir medias/complete/comics

