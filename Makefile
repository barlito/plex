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

.PHONY: init
init:
	@echo "Creating directory structure..."
	@mkdir -p medias/incomplete
	@mkdir -p medias/complete/Films
	@mkdir -p medias/complete/Series
	@mkdir -p medias/complete/Animes
	@mkdir -p medias/complete/books
	@mkdir -p medias/complete/comics
	@mkdir -p filebrowser
	@mkdir -p plex/config
	@mkdir -p radarr/config
	@mkdir -p sonarr/config
	@mkdir -p prowlarr/config
	@mkdir -p emby/config
	@mkdir -p jellyfin/config
	@mkdir -p transmission/config
	@mkdir -p transmission/watch
	@mkdir -p ubooquity/config
	@touch filebrowser/database.db
	@echo "✓ Directory structure ready for production!"

.PHONY: create-subdir
create-subdir:
	touch ./filebrowser/database.db
	mkdir medias/complete/books
	mkdir medias/complete/comics

