 #!/bin/bash

 ##
 : <<'DOCUMENTACAO'
funcao checkDeploy
 Verifica a existencia do phploy.ini e da pasta .git.
 Verifica se esta instalado o git e o phploy
DOCUMENTACAO

function checkDeploy(){
  if [ ! -f "phploy.ini" ]; then
    echo "Erro : PHPloy ini não encontrado nesse caminho; execute deploy.sh -i para instalar "
    exit
  fi
  if [ ! -d ".git" ];then
    echo "Erro : Essa pasta não é um repositório git; execute deploy.sh -i para instalar ou configure manualmente "
    exit
  fi

  type  git > /dev/null 2>&1 || { echo >&2 "Erro :Git é necessário mas não está instalado. execute deploy.sh -i para instalar ou instale manualmente"; exit 1; }

  type  phploy > /dev/null  2>&1 || { echo >&2 "Erro :phploy Git é necessário mas não está instalado de forma global. execute deploy.sh -i para instalar ou instale manualmente"; exit 1; }

}

: <<'DOCUMENTACAO'
funcao deploy
Função que realmente realiza o deploy. Realiza um git pull e verifica as alterações. E realiza o deploy via ftp.
-s ou --servername Realiza deploy somente para o servidor informado
-l Apenas lista as alterações
DOCUMENTACAO

function deploy(){
  echo "git pull do host $host:"
  read -r -p  "   Informe seu usuário: " user
  read -s -r -p "   Informe sua senha: " pass
  echo '';
  command git pull https://$user:$pass@$host $branch   2>&1 || { echo >&2 "Erro : Erro ao executar o git pull"; exit 1; }

  if [ $# -lt 1  ];then
    parametros=""
  elif [ "$1" = "-s" ] || [ "$1" = "--servername" ];then
    if [ -z $2 ];then
       echo "Erro: Comando com $1 mas nome do servidor não foi informado";
       exit
    fi
    parametros="-s $2"
  elif [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
    parametros="-l"
  fi
  echo ""
  echo "Checando diferenças no ftp:"
  echo ""
  command phploy $parametros  2>&1  || { echo >&2 "Erro : Erro ao executar o phploy"; exit 1; }
  #####TESTES#####
  #command php /home/vinicius/Workspace/phploy/phploy.php $parametros  2>&1  || { echo >&2 "Erro : Erro ao executar o phploy"; exit 1; }
  #####TESTES#####
}

function makeDeployini(){

  command  touch deploy.ini ||{ echo >&2 "Erro : Não foi possivel criar deploy.ini"; exit 1;}
  echo "#host do git" >> deploy.ini
  echo "host=host/folder/repo.git" >> deploy.ini
  echo " " >> deploy.ini
  echo "#branch">>deploy.ini
  echo "branch=master">>deploy.ini
  echo " ">>deploy.ini
  echo "#ftp de servidores(Quantos quiser):" >> deploy.ini
  echo "#construido em forma de array:" >> deploy.ini
  echo "# servers = ([\"nome do servidor1\"] =  usuario:senha@servidor1/caminho [\"nome do servidor2\"] =  usuario:senha@servidor2/caminho ...)" >> deploy.ini

  echo "declare -A servers=(
    [\"teste\"]=\"user@url/caminho\"
    [\"producao\"]=\"user@url/caminho\"
    )">> deploy.ini

}

function installPHPloy(){
  echo "Instalando phploy..."
  command wget https://github.com/banago/PHPloy/raw/master/bin/phploy.phar 2>&1 ||{ echo >&2 "Erro : Não foi possivel fazer downlaod de  phploy.phar"; exit 1; } # Baixa do git o phploy
  command sudo cp phploy.phar /usr/local/bin/phploy 2>&1 ||{ echo >&2 "Erro : Não foi possivel mover phploy para usr/local/bin"; exit 1; } #Move phploy para a pasta que faz parte d PATH do sistema, para conseguir executar direto como comando
  command sudo chmod +x /usr/local/bin/phploy 2>&1 ||{ echo >&2 "Erro : Não foi possivel mover phploy para usr/local/bin"; exit 1; } #Adiciona permissão de execução para qualquer usuário


}

function makeInstall(){
  #
  # Inicia uma nova configuração do zero
  #
  if [ -d ".git" ];then
      repo=`git remote -v |grep fetch |cut -d ' ' -f 1| cut -d '@'  -f 2 `
      echo $repo;
      if [ -z "$repo" ] || [ $repo != $host ];then

        while true ;do
          if [ -z $repo ];then
           read -p "Existe uma configuração git nessa pasta e esta corrompido. Remover configuração git? (y/n) " yn
         else
           read -p "Existe uma configuração git nessa pasta em outro servidor remoto. Remover configuração git? (y/n) " yn
         fi
         if [ $yn == y -o $yn == Y ];then
              sudo rm .git -r
              break
         elif [ $yn == n -o $yn == N ];then
            echo "Instalação interrompida"
            exit 1
          else
           echo "Responda sim ou não."
         fi
       done
      fi
  fi
  echo "Configurando o git..."
  if [ ! -d ".git" ];then
    read -r -p  "Informe seu usuário do repositório: " user
    read -s -r -p "Informe sua senha: " pass
    echo "executando..."
    command git init 2>&1 ||{ echo >&2 "Erro : Erro no comando git init"; exit 1; } #executa git init ou retorna erro
    command git remote add origin https://$user:$pass@$host 2>&1 ||{ echo >&2 "Erro : Erro no comando git remote add origin"; exit 1; } #executa git init ou retorna erro
    command git fetch https://$user:$pass@$host $branch 2>&1 ||{ echo >&2 "Erro : Erro no comando git fetch"; exit 1; } #executa git init ou retorna erro
    command git pull https://$user:$pass@$host $branch  2>&1 ||{ echo >&2 "Erro : Erro no comando git pull"; exit 1; } #executa git init ou retorna erro
  fi

  if [ -f "phploy.ini" ]; then
    echo "Removendo antigo phploy.ini"
    command rm phploy.ini ||{ echo >&2 "Erro : Não foi possivel remover phploy.ini. Remova manualmente ou mude as permissões da pasta"; exit 1;}
  fi

    echo "Criando phploy.ini"
    touch phploy.ini

  if [ 0 != ${#servers[*]} ];then #existe a variavel $staging
    for i in "${!servers[@]}"
    do
      echo "Criando servidor $i... "
      echo "[$i]"  >> phploy.ini
       sftp=$(echo ${servers[$i]}| cut -d':' -f 1)
      userftp=$(echo ${servers[$i]}|  cut -d'\' -f 2 | cut -d'@' -f 1)
      url=$(echo ${servers[$i]}| cut -d'@' -f 2 | cut -d'/' -f 1 | cut -d':' -f 1 )
      path=$(echo ${servers[$i]}| cut -d'@' -f 2 | cut  -d'/' -f 2-)
      echo "  scheme = $sftp" >> phploy.ini
      echo "  user = $userftp" >> phploy.ini
      echo "  host = $url" >> phploy.ini
      echo "  path = /$path" >> phploy.ini
      if [ "$sftp" = "sftp" ];then
        echo "  port = 22" >> phploy.ini
      else
       echo "  port = 21" >> phploy.ini
      fi;
      #echo "  quickmode = ${servers[$i]}"  >> phploy.ini
    done

  else
    echo "Erro: Servidores não definidos no arquivo deploy.ini"
    exit
  fi

}

DIR="$( pwd )"



if [ ! "$1" = "-i" ]; then

  if [ ! -f "deploy.ini" ];then
    echo "Erro : deploy.ini não encontrado nesse caminho; execute deploy.sh -i para instalar "
    exit
  fi

fi

if [ -f "deploy.ini" ];then
  source $DIR/deploy.ini
fi





if [ $# -lt 1  ] || [ "$1" = "-s" ] || [ "$1" = "--servername" ] || [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
  echo "Iniciando procedimentos de deploy..."
  checkDeploy $1 $2
  deploy
  exit



  #Se é comando para instalar o script no computador.
elif [ "$1" = "-i" ];then
  #
  # Verificação do caminho inserido no deploy.ini:
  #
  #echo "Checando a existencia do deploy.ini na pasta"
  if [ !  -f "deploy.ini" ]; then

    makeDeployini
    echo "deploy.ini criado na pasta. Configure-o com gedit deploy.ini e rode novamente deploy.sh -i"
    exit
  fi


  #
  # Instalação do git:
  #
  echo "Checando Git..."
  if ! type "git" > /dev/null; then #verifica se git existe
    echo "Instalando git..."
    command sudo apt-get install git 2>&1 ||{ echo >&2 "Erro : Não foi possivel  instalar git"; exit 1; } #instala o git ou retorna erro
  else
    echo "Git já está instalado"
  fi

  #
  # Instalação do PHPloy:
  #
  echo "Checando PHPloy..."
  if ! phploy_loc="$(type -p "phploy")" || [ -z "$phploy_loc" ]; then #verifica se o phploy existe e se não é um alias
    installPHPloy
  else
    echo "PHPloy já está instalado"
  fi


  #cd $path

  makeInstall


else
  echo $1 não foi reconhecido

fi
