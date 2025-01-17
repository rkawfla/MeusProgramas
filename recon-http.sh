#!/bin/bash

# Verifica se os argumentos foram fornecidos
if [ $# -ne 4 ]; then
    echo "Uso: $0 <protocolo> <host> <porta> <diretorio>"
    exit 1
fi

# Extrai os parâmetros de entrada
protocolo=$1
host=$2
porta=$3
diretorio=$4

# Variáveis de cores
padrao=$'\033[0m'
verde=$'\033[0;32m'
vermelho=$'\033[0;31m'
azul=$'\033[0;34m'
amarelo=$'\033[0;33m'

# Função para imprimir em verde (aceito) e vermelho (não aceito)
color_print() {
    local metodo=$1
    local code=$2
    local legenda=$3

    # Formata a linha conforme solicitado
    formatted_output=$(printf "%-8s | %-3s | %-90s" "$metodo" "$code" "$legenda")

    # Verifica se o código de status é 2xx (aceito)
    if [[ "$code" =~ ^2[0-9]{2}$ ]]; then
        # Se for 2xx, imprime em verde
        echo -e "${verde}$formatted_output${padrao}"
    else
        # Caso contrário, imprime em vermelho
        echo -e "${vermelho}$formatted_output${padrao}"
    fi
}

# Função para enviar requisição HTTP ou HTTPS com fallback
send_request() {
    local metodo=$1
    local protocolo=$2
    local host=$3
    local porta=$4
    local diretorio=$5

    # Tenta fazer a requisição com curl
    http_code=$(curl --max-time 3 -k -s -o /dev/null -w "%{http_code}" "$protocolo://$host:$porta$diretorio" -X "$metodo" -L)

    # Se o código de resposta for vazio ou curl falhou, tenta com nc ou openssl
    if [ -z "$http_code" ]; then
        echo "Curl falhou, tentando com netcat ou openssl..."

        # Usar openssl para HTTPS ou netcat para HTTP
        if [ "$protocolo" == "https" ]; then
            # Usar openssl para HTTPS
            response=$(echo -e "$header" | openssl s_client -quiet -connect "$host:$porta" 2>/dev/null)
        elif [ "$protocolo" == "http" ]; then
            # Usar netcat para HTTP
            response=$(echo -e "$header" | nc "$host" "$porta" 2>/dev/null)
        else
            echo "Protocolo inválido"
            exit 1
        fi
    else
        response=$http_code
    fi

    echo "$response"
}

# Função para mapear o código de status para português com base no MDN
map_status() {
    local code=$1

    case "$code" in
        100) echo "CONTINUE                        | O servidor recebeu a solicitação e precisa de mais informações." ;;
        101) echo "SWITCHING PROTOCOLS             | O servidor está mudando o protocolo de acordo com o solicitado." ;;
        102) echo "PROCESSING                      | O servidor está processando a solicitação, mas ainda não há resposta." ;;
        200) echo "OK                              | A solicitação foi bem-sucedida." ;;
        201) echo "CREATED                         | A solicitação foi bem-sucedida e resultou na criação de um recurso." ;;
        202) echo "ACCEPTED                        | A solicitação foi aceita, mas ainda não processada." ;;
        203) echo "NON-AUTHORITATIVE INFORMATION   | A resposta contém informações não autoritativas." ;;
        204) echo "NO CONTENT                      | A solicitação foi bem-sucedida, mas não há conteúdo a ser retornado." ;;
        205) echo "RESET CONTENT                   | A solicitação foi bem-sucedida, mas a página deve ser redefinida." ;;
        206) echo "PARTIAL CONTENT                 | O servidor está retornando uma parte do conteúdo solicitado." ;;
        207) echo "MULTI|STATUS                    | A solicitação inclui múltiplos estados de resposta." ;;
        208) echo "ALREADY REPORTED                | O item foi já reportado." ;;
        226) echo "IM USED                         | O servidor está usando um recurso, conforme especificado na solicitação." ;;
        300) echo "MULTIPLE CHOICES                | A solicitação tem várias opções, o usuário deve escolher." ;;
        301) echo "MOVED PERMANENTLY               | O recurso foi movido permanentemente para uma nova URL." ;;
        302) echo "MOVED TEMPORARILY               | O recurso foi movido temporariamente para uma nova URL." ;;
        303) echo "SEE OTHER                       | O recurso solicitado está disponível em outro URI." ;;
        304) echo "NOT MODIFIED                    | O recurso não foi modificado desde a última solicitação." ;;
        305) echo "USE PROXY                       | O recurso deve ser acessado através de um proxy." ;;
        306) echo "SWITCH PROXY                    | O servidor solicita que o proxy seja alterado." ;;
        307) echo "TEMPORARY REDIRECT              | O recurso foi temporariamente movido para uma nova URL." ;;
        308) echo "PERMANENT REDIRECT              | O recurso foi permanentemente movido para uma nova URL." ;;
        400) echo "BAD REQUEST                     | A solicitação não foi compreendida pelo servidor." ;;
        401) echo "UNAUTHORIZED                    | A solicitação requer autenticação." ;;
        402) echo "PAYMENT REQUIRED                | A solicitação requer pagamento." ;;
        403) echo "FORBIDDEN                       | O servidor recusou a solicitação." ;;
        404) echo "NOT FOUND                       | O recurso solicitado não foi encontrado." ;;
        405) echo "METHOD NOT ALLOWED              | O método HTTP não é permitido para o recurso." ;;
        406) echo "NOT ACCEPTABLE                  | O recurso não pode gerar uma resposta aceitável." ;;
        407) echo "PROXY AUTHENTICATION REQUIRED   | Autenticação é necessária para o proxy." ;;
        408) echo "REQUEST TIMEOUT                 | O servidor não recebeu a solicitação dentro do tempo esperado." ;;
        409) echo "CONFLICT                        | O pedido não pode ser processado devido a um conflito." ;;
        410) echo "GONE                            | O recurso não está mais disponível." ;;
        411) echo "LENGTH REQUIRED                 | O servidor exige que o comprimento da solicitação seja especificado." ;;
        412) echo "PRECONDITION FAILED             | A solicitação falhou devido a precondições não atendidas." ;;
        413) echo "PAYLOAD TOO LARGE               | O tamanho do conteúdo da solicitação é maior que o permitido." ;;
        414) echo "URI TOO LONG                    | A URI da solicitação é muito longa." ;;
        415) echo "UNSUPPORTED MEDIA TYPE          | O tipo de mídia da solicitação não é suportado." ;;
        416) echo "RANGE NOT SATISFIABLE           | O servidor não pode atender ao intervalo solicitado." ;;
        417) echo "EXPECTATION FAILED              | O servidor não conseguiu atender a expectativa fornecida." ;;
        418) echo "I'M A TEAPOT RFC 2324           | O servidor se recusa a processar a solicitação, alegando ser um bule de chá." ;;
        421) echo "MISDIRECTED REQUEST             | A solicitação foi direcionada a um servidor incorreto." ;;
        422) echo "UNPROCESSABLE ENTITY            | O servidor entende o conteúdo da solicitação, mas não pode processá-la." ;;
        423) echo "LOCKED                          | O recurso está bloqueado e não pode ser acessado." ;;
        424) echo "FAILED DEPENDENCY               | A solicitação falhou devido a uma dependência não atendida." ;;
        425) echo "TOO EARLY                       | A solicitação foi feita antes de um tempo adequado." ;;
        426) echo "UPGRADE REQUIRED                | O servidor exige que a solicitação seja atualizada." ;;
        427) echo "PRECONDITION REQUIRED           | O servidor exige que a solicitação atenda a determinadas condições." ;;
        428) echo "MUST FULFILL REQUIREMENTS       | A solicitação deve atender aos requisitos." ;;
        429) echo "TOO MANY REQUESTS               | O número de solicitações feitas foi excessivo." ;;
        431) echo "REQUEST HEADER FIELDS TOO LARGE | Os campos do cabeçalho da solicitação são muito grandes." ;;
        451) echo "UNAVAILABLE FOR LEGAL REASONS   | O recurso não está disponível por motivos legais." ;;
        500) echo "INTERNAL SERVER ERROR           | O servidor encontrou um erro interno e não pode processar a solicitação." ;;
        501) echo "NOT IMPLEMENTED                 | O servidor não suporta a funcionalidade necessária para processar a solicitação." ;;
        502) echo "BAD GATEWAY                     | O servidor recebeu uma resposta inválida de um servidor upstream." ;;
        503) echo "SERVICE UNAVAILABLE             | O servidor não está disponível para processar a solicitação." ;;
        504) echo "GATEWAY TIMEOUT                 | O servidor não obteve uma resposta a tempo de um servidor upstream." ;;
        505) echo "HTTP VERSION NOT SUPPORTED      | O servidor não suporta a versão do HTTP usada na solicitação." ;;
        506) echo "VARIANT ALSO NEGOTIATES         | O servidor encontrou uma falha na negociação de conteúdo." ;;
        507) echo "INSUFFICIENT STORAGE            | O servidor não tem capacidade suficiente para processar a solicitação." ;;
        508) echo "LOOP DETECTED                   | O servidor detectou um loop infinito ao processar a solicitação." ;;
        510) echo "NOT EXTENDED                    | O servidor exige extensão de funcionalidade." ;;
        511) echo "NETWORK AUTHENTICATION REQUIRED | O acesso à rede requer autenticação." ;;
        ***) echo "DESCONHECIDO                    | Código não reconhecido." ;;  # Caso o código não seja reconhecido
    esac
}

# Imprime o cabeçalho
echo ""
echo "${azul}#########################################################[ TIPOS DE CÓDIGOS ]#########################################################${padrao}"
echo "${amarelo}Informativas (100-199) | Bem-Sucedidas (200-299) | Redirecionamento (300-399) | Erro do Cliente (400-499) | Erro do Servidor (500-599)${padrao}"
echo "--------------------------------------------------------------------------------------------------------------------------------------"
echo "  MÉTODO | CÓD |            LEGENDA              |                            DESCRIÇÃO                               "
echo "--------------------------------------------------------------------------------------------------------------------------------------"

# Loop para testar os métodos HTTP no diretório especificado
for webservmethod in HEAD GET POST OPTIONS PUT TRACE CONNECT PROPFIND DELETE PATCH; do
    # Envia a requisição e captura a resposta
    http_code=$(send_request "$webservmethod" "$protocolo" "$host" "$porta" "$diretorio")
    
    # Mapeia o código para o status em português
    status=$(map_status "$http_code")

    # Chama a função para imprimir a linha com a cor correta
    color_print "$webservmethod" "$http_code" "$status"
done
