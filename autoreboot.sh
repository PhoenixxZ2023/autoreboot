#!/bin/bash

# Adiciona a tarefa ao crontab
(crontab -l ; echo "0 */12 * * * /sbin/shutdown -r now") | crontab -
