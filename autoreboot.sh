#!/bin/bash

sshplus_path="/etc/SSHPlus"
menu_file="$sshplus_path/menu"
cron_file="$sshplus_path/crontab"

show_menu() {
    echo "Selecione uma opção:"
    echo "1. Agendar reinicialização do servidor"
    echo "2. Sair"
}

show_reboot_menu() {
    echo "Selecione a frequência de reinicialização:"
    echo "1. A cada 6 horas"
    echo "2. A cada 12 horas"
    echo "3. A cada 24 horas"
    echo "4. Voltar ao menu principal"
}

schedule_reboot() {
    case $1 in
        1) cron_expression="0 */6 * * *";;
        2) cron_expression="0 */12 * * *";;
        3) cron_expression="0 0 * * *";;
        *) return;;
    esac

    (crontab -l ; echo "$cron_expression /sbin/shutdown -r now") | crontab -
    echo "Reinicialização agendada com sucesso!"
    echo "$cron_expression /sbin/shutdown -r now" >> $cron_file
}

while true
do
    show_menu
    read choice

    case $choice in
        1)
            while true
            do
                show_reboot_menu
                read reboot_choice

                case $reboot_choice in
                    1|2|3) schedule_reboot $reboot_choice;;
                    4) break;;
                    *) echo "Opção inválida.";;
                esac
            done
            ;;
        2) break;;
        *) echo "Opção inválida.";;
    esac
done
