SHELL := /bin/bash


update:
	@echo "${Update_MSG}"
	@git add .
	@git commit -m "Update"
	@git push
	@echo "✨ Mise à jour terminée✨"
