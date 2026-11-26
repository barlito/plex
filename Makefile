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

.PHONY: recyclarr-sync
recyclarr-sync:
	@id=$$(docker ps -q -f name=$(stack_name)_recyclarr); \
	if [ -z "$$id" ]; then \
		echo "No local $(stack_name)_recyclarr container: run this on the node hosting the task" >&2; \
		exit 1; \
	fi; \
	docker exec $$id recyclarr sync

.PHONY: cross-seed-search
cross-seed-search:
	@id=$$(docker ps -q -f name=$(stack_name)_cross-seed); \
	if [ -z "$$id" ]; then \
		echo "No local $(stack_name)_cross-seed container: run this on the node hosting the task" >&2; \
		exit 1; \
	fi; \
	docker exec $$id sh -c 'curl -fsS -XPOST "http://localhost:2468/api/job?apikey=$$CROSS_SEED_API_KEY" -d name=search -d ignoreExcludeRecentSearch=true -d ignoreExcludeOlder=true'

.PHONY: init
init:
	@echo "Creating directory structure..."
	@mkdir -p medias/incoming
	@mkdir -p medias/cross-seed
	@mkdir -p medias/incomplete
	@mkdir -p medias/complete/Films
	@mkdir -p medias/complete/SeriesTV
	@mkdir -p medias/complete/Animes
	@mkdir -p medias/complete/books
	@mkdir -p medias/complete/comics
	@mkdir -p filebrowser
	@mkdir -p plex/config
	@mkdir -p radarr/config
	@mkdir -p sonarr/config
	@mkdir -p prowlarr/config
	@mkdir -p bazarr/config
	@mkdir -p seerr/config
	@mkdir -p emby/config
	@mkdir -p jellyfin/config
	@mkdir -p transmission/config
	@mkdir -p transmission/watch
	@mkdir -p ubooquity/config
	@mkdir -p recyclarr/config
	@mkdir -p cross-seed/config
	@touch filebrowser/database.db
	@echo "✓ Directory structure ready for production!"

.PHONY: create-subdir
create-subdir:
	touch ./filebrowser/database.db
	mkdir medias/complete/books
	mkdir medias/complete/comics

