#!/bin/bash
#
# EHEH Agent Installation Script
#
# @version		1.0.0
# @date			2020-09-21
# @copyright: The script baseon nodequery.com/nq-agent project under mit license
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Set environment
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Prepare output
echo -e "|\n|   EHEH 一键安装\n|   ===================\n|"

# Root required
if [ $(id -u) != "0" ];
then
	echo -e "|   Error: 你需要用root账号执行该脚本\n|"
	echo -e "|          安装脚本将创建一个EHEH账号用来定时执行脚本\n|"
	exit 1
fi

# Parameters required
if [ $# -lt 1 ]
then
	echo -e "|   用法: bash $0 'token'\n|"
	exit 1
fi


#delete exits data
echo "|" && read -p "|   安装将删除本地的以前记录  [Y/n] " input_del
if [ -z $input_del ] || [ $input_del == "Y" ] || [ $input_del == "y" ]
then
  #uninstall
  rm -Rf /etc/EHEH
  crontab -u EHEH -r
  userdel EHEH
else
  exit 1
fi


# Check if crontab is installed
if [ ! -n "$(command -v crontab)" ]
then

	# Confirm crontab installation
	echo "|" && read -p "|   当前系统没安装Crontab，无法定时推送数据，安装吗？?  [Y/n] " input_variable_install

	# Attempt to install crontab
	if [ -z $input_variable_install ] || [ $input_variable_install == "Y" ] || [ $input_variable_install == "y" ]
	then
		if [ -n "$(command -v apt-get)" ]
		then
			# echo -e "|\n|   Notice: Installing required package 'cron' via 'apt-get'"
		    apt-get -y update
		    apt-get -y install cron
		elif [ -n "$(command -v yum)" ]
		then
			# echo -e "|\n|   Notice: Installing required package 'cronie' via 'yum'"
		    yum -y install cronie

		    if [ ! -n "$(command -v crontab)" ]
		    then
		    	# echo -e "|\n|   Notice: Installing required package 'vixie-cron' via 'yum'"
		    	yum -y install vixie-cron
		    fi
		elif [ -n "$(command -v pacman)" ]
		then
			# echo -e "|\n|   Notice: Installing required package 'cronie' via 'pacman'"
		    pacman -S --noconfirm cronie
		fi
	fi

	if [ ! -n "$(command -v crontab)" ]
	then
	    # Show error
	    echo -e "|\n|   Error: Crontab is required and could not be installed\n|"
	    exit 1
	fi
fi

# Check if cron is running
if [ -z "$(ps -Al | grep cron | grep -v grep)" ]
then

	# Confirm cron service
	echo "|" && read -p "|   系统定时任务Crontab没启动，要启动吗? [Y/n] " input_variable_service

	# Attempt to start cron
	if [ -z $input_variable_service ] || [ $input_variable_service == "Y" ] || [ $input_variable_service == "y" ]
	then
		if [ -n "$(command -v apt-get)" ]
		then
			# echo -e "|\n|   Notice: Starting 'cron' via 'service'"
			service cron start
		elif [ -n "$(command -v yum)" ]
		then
			# echo -e "|\n|   Notice: Starting 'crond' via 'service'"
			chkconfig crond on
			service crond start
		elif [ -n "$(command -v pacman)" ]
		then
			# echo -e "|\n|   Notice: Starting 'cronie' via 'systemctl'"
		    systemctl start cronie
		    systemctl enable cronie
		fi
	fi

	# Check if cron was started
	if [ -z "$(ps -Al | grep cron | grep -v grep)" ]
	then
		# Show error
		echo -e "|\n|   Error: Crontab定时任务没启动\n|"
		exit 1
	fi
fi

# Attempt to delete previous agent
if [ -f /etc/EHEH/eheh-agent.sh ]
then
	# Remove agent dir
	rm -Rf /etc/EHEH

	# Remove cron entry and user
	if id -u EHEH >/dev/null 2>&1
	then
		(crontab -u EHEH -l | grep -v "/etc/EHEH/eheh-agent.sh") | crontab -u EHEH - && userdel EHEH
	else
		(crontab -u root -l | grep -v "/etc/EHEH/eheh-agent.sh") | crontab -u root -
	fi
fi

# Create agent dir
mkdir -p /etc/EHEH

# Download agent
echo -e "|   下载脚本到 /etc/EHEH\n|\n|   + $(wget -nv -o /dev/stdout -O /etc/EHEH/eheh-agent.sh --no-check-certificate https://raw.github.com/eheh-org/agent/master/eheh-agent.sh)"

if [ -f /etc/EHEH/eheh-agent.sh ]
then
	# Create auth file
	echo "$1" > /etc/EHEH/eheh-auth.log

	# Create user
	useradd EHEH -r -d /etc/EHEH -s /bin/false

	# Modify user permissions
	chown -R EHEH:EHEH /etc/EHEH && chmod -R 700 /etc/EHEH

	# Modify ping permissions
	chmod +s `type -p ping`

	# Configure cron
	crontab -u EHEH -l 2>/dev/null | { cat; echo "*/3 * * * * bash /etc/EHEH/eheh-agent.sh > /etc/EHEH/eheh-cron.log 2>&1"; } | crontab -u EHEH -

	# Show success
	echo -e "|\n|   小提示：如果你的服务器安装有宝塔，crontab可能被停用了，请参考：https://eheh.org/article/10 进行设置下"
	echo -e "|\n|   小提示：如果你的服务使用了Cpanel，ping可能缺少权限，请参考https://eheh.org/article/6 进行设置下"
	echo -e "|   Success: 安装完成\n|"

  echo "|" && read -p "|   你想监控mysql状态吗，如果要请输入Y，我们将帮你设置  [Y/n] " input_mysql
  if [ -z $input_mysql ] || [ $input_mysql == "Y" ] || [ $input_mysql == "y" ]
  then
        echo "|" && read -p "|  请输入mysql用户名  " input_mu
        $(echo "$input_mu" > /etc/EHEH/mysql-user)

        echo "|" && read -p "|  请输入mysql密码  " input_mp
        $(echo "$input_mp" > /etc/EHEH/mysql-pass)

        echo -e "|\n|   Done,完成设置"
  fi

  #push data at once ?
  echo "|" && read -p "|   需要马上推送数据吗？或等5/6分钟  [Y/n] " push
  if [ $push == "Y" ] || [ $push == "y" ]
  then
    sh /etc/EHEH/eheh-agent.sh
    chown -Rf EHEH.EHEH /etc/EHEH/
  fi

  echo -e "|\n| 完成安装！EHEH.ORG 上见\n|"

	# Attempt to delete installation script
	if [ -f $0 ]
	then
		rm -f $0
	fi
else
	# Show error
	echo -e "|\n|  错误，无法安装\n|"
fi