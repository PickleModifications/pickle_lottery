fx_version 'cerulean'
lua54 'yes'
game 'gta5'

name         'pickle_lottery'
version      '1.2.1'
description  'A fully immersive lottery system.'
author       'Pickle Mods'

ui_page "nui/index.html"

files {
    "nui/index.html",
    "nui/assets/**/*.*",
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'core/shared.lua',
    "locales/*.lua",
    'modules/**/shared.lua',
}

server_scripts {
	"@mysql-async/lib/MySQL.lua",
    'core/server.lua',
    'bridge/**/server.lua',
    'modules/**/server.lua',
    'discord.lua',
}

client_scripts {
    'core/client.lua',
    'bridge/**/client.lua',
    'modules/**/client.lua',
}

escrow_ignore {
	"config.lua",
	"discord.lua",
	"_INSTALL/**/*.*",
	"bridge/**/**/*.*",
	"bridge/**/*.*",
    "locales/*.lua",

	-- COMMENT BELOW IF NOT SOURCE --

	"modules/**/*.*",
	"core/*.*",
}
dependency '/assetpacks'