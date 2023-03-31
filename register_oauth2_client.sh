#!/bin/bash
docker compose exec -T irisrsc iris session iris -U MYRSC "Register^API.Register"
docker compose exec -T irisrsc2 iris session iris -U MYRSC "Register^API.Register"
docker compose exec -T irisclient iris session iris -U USER "Register^MyApp.RegisterAll"
docker compose exec -T irisclient2 iris session iris -U USER "Register^MyApp.RegisterAll"
