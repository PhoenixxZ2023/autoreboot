#!/bin/bash

# Verifica se o sistema é Debian ou Ubuntu
verificar_sistema() {
    local distro=$(lsb_release -i | cut -f 2)
    if [[ "$distro" != "Debian" && "$distro" != "Ubuntu" ]]; then
        echo "Este script suporta apenas Debian e Ubuntu."
        exit 1
    fi
}

# Função para instalar o cron
instalar_cron() {
    echo "Tentando instalar o cron..."
    sudo apt-get update
    sudo apt-get install -y cron
    if ! systemctl is-active --quiet cron; then
        echo "Falha ao instalar ou iniciar o cron."
        exit 1
    fi
}

# Verifica se o cron está instalado e em execução
if ! command -v cron >/dev/null 2>&1 || ! systemctl is-active --quiet cron; then
    echo "O cron não está instalado ou em execução."
    read -p "Deseja instalar o cron? [s/N] " resposta
    case "$resposta" in
        [sS]|[sS][iI][mM])
            instalar_cron
            ;;
        *)
            echo "Este script requer o cron para ser executado."
            exit 1
            ;;
    esac
fi

# Função para adicionar uma nova tarefa de reinicialização com um comentário descritivo
adicionar_tarefa_reinicializacao() {
    local frequencia dia hora minuto agendamento comentario

    # Obter frequência
    while true; do
        read -p "Escolha a frequência da tarefa de reinicialização (1. Mensal, 2. Semanal, 3. Diário): " frequencia
        if [[ $frequencia =~ ^[1-3]$ ]]; then
            break
        else
            echo "Entrada inválida. Por favor, informe 1, 2 ou 3."
        fi
    done

    # Obter dia, hora, minuto com base na frequência
    case $frequencia in
        1) # Mensal
            while true; do
                read -p "Informe o dia do mês (1-28): " dia
                if [[ $dia =~ ^[1-9]$|^1[0-9]$|^2[0-8]$ ]]; then
                    break
                else
                    echo "Dia inválido. Por favor, informe um número entre 1 e 28."
                fi
            done
            ;;
        2) # Semanal
            while true; do
                read -p "Informe o dia da semana (1-7, onde 1 é segunda-feira): " dia
                if [[ $dia =~ ^[1-7]$ ]]; then
                    break
                else
                    echo "Dia inválido. Por favor, informe um número entre 1 e 7."
                fi
            done
            ;;
        3) # Diário
            dia="*"
            ;;
    esac

    # Obter hora
    while true; do
        read -p "Informe a hora da reinicialização (0-23): " hora
        if [[ $hora =~ ^[0-1]?[0-9]$|^2[0-3]$ ]]; then
            break
        else
            echo "Hora inválida. Por favor, informe um número entre 0 e 23."
        fi
    done

    # Obter minuto
    while true; do
        read -p "Informe o minuto da reinicialização (0-59): " minuto
        if [[ $minuto =~ ^[0-5]?[0-9]$ ]]; then
            break
        else
            echo "Minuto inválido. Por favor, informe um número entre 0 e 59."
        fi
    done

    # Criar a string de agendamento e o comentário
    if [[ $frequencia == 1 ]]; then  # Mensal
        agendamento="$minuto $hora $dia * *"
        comentario="Tarefa Mensal de Reinicialização - Dia: $dia, Horário: $hora:$minuto"
    elif [[ $frequencia == 2 ]]; then  # Semanal
        agendamento="$minuto $hora * * $dia"
        comentario="Tarefa Semanal de Reinicialização - Dia da Semana: $dia, Horário: $hora:$minuto"
    else  # Diário
        agendamento="$minuto $hora * * *"
        comentario="Tarefa Diária de Reinicialização - Horário: $hora:$minuto"
    fi

    # Adicionar o comentário e a tarefa cron
    echo "Adicionando tarefa cron: $comentario"
    (crontab -l 2>/dev/null; echo "# $comentario"; echo "$agendamento sudo shutdown -r now") | crontab -
    if [ $? -eq 0 ]; then
        echo "Tarefa de reinicialização adicionada."
    else
        echo "Falha ao adicionar tarefa de reinicialização. Verifique o formato da entrada."
    fi
}

# Função para listar as tarefas de reinicialização atuais em um formato legível
listar_tarefas_reinicializacao() {
    local linha_cabecalho_rodape=$(printf '%.0s#' {1..40}) # Ajuste o número para a largura desejada
    local linha_separadora_tarefas=$(printf '%.0s-' {1..40}) # Ajuste o número para a largura desejada
    echo "$linha_cabecalho_rodape"
    local IFS=$'\n'
    local contagem_tarefas=0
    local linhas_cron=($(crontab -l))
    local total_tarefas=$(grep -c '^#' <<< "${linhas_cron[*]}")

    for linha in "${linhas_cron[@]}"; do
        if [[ "$linha" == \#* ]]; then
            ((contagem_tarefas++))
            [[ $contagem_tarefas -gt 1 ]] && echo "$linha_separadora_tarefas" # Separador entre tarefas
            echo "Tarefa $contagem_tarefas: ${linha/#\# }"
        elif [ $contagem_tarefas -gt 0 ]; then
            echo "Cron: $linha"
        fi
    done

    if [ $contagem_tarefas -eq 0 ]; then
        echo "Nenhuma reinicialização agendada encontrada."
    fi
    echo "$linha_cabecalho_rodape"
}

# Função para excluir uma tarefa de reinicialização
excluir_tarefa_reinicializacao() {
    echo "Selecione o número da tarefa a ser excluída:"
    
