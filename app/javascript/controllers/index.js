import { application } from "controllers/application"

// Import and register all your controllers from the importmap under controllers/*
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
