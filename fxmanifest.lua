fx_version 'cerulean'
game 'gta5'

author 'TwoEggsJP'
description 'Modern Shop Script - Versão Otimizada e Segura'
version '1.2.0'

ui_page 'html/index.html'

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

shared_script 'config.lua'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/img/*.png'
}