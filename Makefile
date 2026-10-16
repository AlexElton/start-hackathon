.PHONY: open backend backend-build models test

open:            ## Open everything in Xcode
	open Hackathon.xcworkspace

backend:         ## Run the Vapor backend on :8080
	cd backend && swift run App serve

backend-build:
	cd backend && swift build

models:          ## Build the shared models package
	cd SharedModels && swift build

test:            ## Run the backend tests
	cd backend && swift test
