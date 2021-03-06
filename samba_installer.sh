if $DATA_TO_EXTERNAL_DISK; then
   DIRECTORY=$EXTERNAL_DATA_DIR/samba
else
   DIRECTORY=/srv/samba
fi

function first_install(){
   yes_no $"Confirmation" $"Do you really want to install Samba Server?"
   clear
   sys_update

   echo $"Installing samba packages..."
   apt-get -qq install samba-common samba-common-bin samba tdb-tools

   addgroup samba-user
   hint_msg $"This setup will create samba shares that are protected by a username and password."
   choice=$"y"
   while [ "$choice" == $"y" ]; do
      echo
      clear
      while true; do
         read -p $"Enter a username: " username &&
         adduser --no-create-home --disabled-login --shell /bin/false --ingroup samba-user $username &&
         break
      done

      while true; do
         smbpasswd -a $username && break
      done

      while true; do
         read -p $"Enter a name for this share: " name
         if grep -q "\[$name\]" /etc/samba/smb.conf; then
            echo $"This share already exists"
         else
            break
         fi
      done
      path=$DIRECTORY/$name &&
      mkdir -p $path &&
      chown -R $username:samba-user $path
      read -p $"Enter a short description of this share: " comment &&
      cat >> /etc/samba/smb.conf << EOF
[$name]
comment = $comment
path = $path
available = yes
browsable = yes
guest ok = no
writable = yes
force user = $username
force group = samba-user
valid users = $username

EOF
      read -p $"Create more shares? (y/n)" choice
   done
}

function add_more_shares(){
   clear
   echo $"Add more shares"
   choice=$"y"
   while [ "$choice" == $"y" ]; do
      echo

      while true; do
         read -p $"Enter a username: " username &&
         adduser --no-create-home --disabled-login --shell /bin/false --ingroup samba-user $username &&
         break
      done

      while true; do
         smbpasswd -a $username && break
      done

      while true; do
         read -p $"Enter a name for this share: " name
         if grep -q "\[$name\]" /etc/samba/smb.conf; then
            echo $"This share already exists"
         else
            break
         fi
      done
      path=$DIRECTORY/$name &&
      mkdir -p $path &&
      chown -R $username:samba-user $path
      read -p $"Enter a short description of this share: " comment &&
      cat >> /etc/samba/smb.conf << EOF &&
[$name]
comment = $comment
path = $path
available = yes
browsable = yes
guest ok = no
writable = yes
force user = $username
force group = samba-user
valid users = $username

EOF
      read -p $"Create more shares? (y/n)" choice
   done
}

function remove_samba(){
   yes_no $"Starting uninstaller" $"Do you really want to remove Samba Server? All shared files and directories will be deleted!" || return 1
   SAMBA_USER_GID=$(cat /etc/group | grep samba-user | cut -d ':' -f3)
   for username in $(cat /etc/passwd | grep $SAMBA_USER_GID | cut -d ':' -f1); do
      smbpasswd -x $username
      deluser --remove-all-files $username 2> /dev/null
   done
   delgroup samba-user
   rm -r $DIRECTORY
   apt-get purge samba tdb-tools
}

case $1 in
   install)
      first_install
      ;;
   add)
      add_more_shares
      ;;
   remove)
      remove_samba
      ;;
esac
