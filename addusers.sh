#!/bin/bash

RED="\e[31;40m";
GREEN="\e[32;40m";
YELLOW="\e[33;40m";
DEFAULT="\e[m";

OPTION="$1";
#echo ${OPTION};
USERNAME="$2";
#echo ${USERNAME};
PHONENUMBER="$3"
#echo ${PHONENUMBER};

#ZBX_ADDR='http://tzabbix.op.dajie-inc.com/api_jsonrpc.php';
ZBX_ADDR='http://zabbix.op.dajie-inc.com/api_jsonrpc.php';
ZBX_ADMIN='admin';
ZBX_ADMIN_PWD='8AkO6Jhew9jcDDcK';

# Useage function
function USEAGE
{
        echo -e "Useage: ${YELLOW}addusers.sh ${RED}[OPTION] ${GREEN}parameter ${DEFAULT}[${GREEN}phonenumber${DEFAULT}]
                          ${RED}-u ${GREEN}username phonenumber     ${DEFAULT}# The single username to be added into the KDC and zabbix system.
                          ${RED}-f ${GREEN}filename                 ${DEFAULT}# The path of file which contain usernames to be added(one username per line)."
}

# Kadmin password function
function KADMINPASSWORD
{
        echo -e "Please enter the password of ${RED}Kadmin${DEFAULT}:";
        read -s -p "Password: " KAP;
        if [[ -z ${KAP} ]]
        then
                echo -e "${RED}Please entry the password of kadmin!${DEFAULT}"
                exit;
        fi
}

function ADDUSERINKDC
{
        #echo ${USERNAME};
        #CHECK_USER=`kadmin -p root/admin -q "listprincs" < /root/kap | grep ${USERNAME}`;
        CHECK_USER=`kadmin -p root/admin -q "listprincs" <<< ${KAP} | grep ${USERNAME}`;
        if [ -z "${CHECK_USER}" ]
        then
                # Add user into kdc
                echo -e "Add user:${RED}${USERNAME}${DEFAULT} into KDC..."
                kadmin -p root/admin -q "addprinc -policy user -pw 123abc... +needchange  ${USERNAME}" <<< ${KAP};
                CHECK_USER=`kadmin -p root/admin -q "listprincs" <<< ${KAP}  | grep ${USERNAME}`;
                if [ -z "${CHECK_USER}" ]
                then
                        echo -e "${RED}User: ${USERNAME} Add Fault!${DEFAULT}";
                else
                        echo -e "${GREEN}User: ${USERNAME} Add Successful!${DEFAULT}";
                fi
        else
                # echo user is already exists
                echo -e "The user: ${RED}${USERNAME}${DEFAULT} is already in KDC."
        fi
}

function ADDUSERINZBX
{
        LOGIN='{
                    "jsonrpc": "2.0",
                    "method": "user.login",
                    "params": {
                        "user": "'${ZBX_ADMIN}'",
                        "password": "'${ZBX_ADMIN_PWD}'"
                    },
                    "id": 1
                }'
        #echo ${LOGIN};
        #AUTH_CODE=`curl -i -X POST -H "Content-Type:application/json" -d "${LOGIN}" ${ZBX_ADDR} 2>/dev/null | awk -F '"' '{print $8}'`;
        AUTH_CODE=`curl -u : --negotiate -i -X POST -H "Content-Type:application/json" -d "${LOGIN}" ${ZBX_ADDR} 2>/dev/null | awk -F '"' '{print $8}'`;
        AUTH_CODE=`echo ${AUTH_CODE}`;
        #echo ${AUTH_CODE};
        ZBX_USER_ADD='{
                            "jsonrpc": "2.0",
                            "method": "user.create",
                            "params": {
                                "alias": "'${USERNAME}'",
                                "name": "'${USERNAME}'",
                                "surname": "'${USERNAME}'",
                                "passwd": "1qaz2wsx,./",
                                "type": "1",
                                "usrgrps": [
                                    {
                                        "usrgrpid": "100100000000008"
                                    },
                                    {
                                        "usrgrpid": "100100000000015"
                                    }
                                ],
                                "user_medias": [
                                    {
                                        "mediatypeid": "100100000000001",
                                        "sendto": "'${USERNAME}'@dajie-inc.com",
                                        "active": 0,
                                        "severity": 48,
                                        "period": "1-7,00:00-24:00"
                                    },
                                    {
                                        "mediatypeid": "100100000000005",
                                        "sendto": "'${PHONENUMBER}'",
                                        "active": 0,
                                        "severity": 48,
                                        "period": "1-7,00:00-24:00"
                                    }
                                ]
                            },
                            "auth": "'${AUTH_CODE}'",
                            "id": 1
                        }';
        #echo ${ZBX_USER_ADD};
        #RESULT=`curl -i -X POST -H "Content-Type:application/json" -d "${ZBX_USER_ADD}" ${ZBX_ADDR} 2>/dev/null`;
        RESULT=`curl -u : --negotiate -i -X POST -H "Content-Type:application/json" -d "${ZBX_USER_ADD}" ${ZBX_ADDR} 2>/dev/null`;
        RESULT="${RESULT}";
        #echo ${RESULT};

        #RESULT_ID=`echo ${RESULT} | grep userids | awk -F '"' '{print $10}'`;
        RESULT_ID=`echo ${RESULT} | grep userids | awk -F '"' '{print $12}'`;

        if [ -n "${RESULT_ID}" ]
        then
                echo -e "The user: ${RED}${USERNAME}${DEFAULT} is added in zabbix,and the userid is: ${GREEN}${RESULT_ID}${DEFAULT}";
        else
                RESULT_ID=`echo ${RESULT} | grep already`;
                if [ -n "${RESULT_ID}" ]
                then
                        echo -e "User: ${RED}${USERNAME}${DEFAULT} is ${RED}already exists${DEFAULT}.";
                else
                        echo -e "${RED}User: ${USERNAME} add Fault!${DEFAULT}";
                fi  
        fi
        LOGOUT='{
                    "jsonrpc": "2.0",
                    "method": "user.logout",
                    "params": [],
                    "id": 1,
                    "auth": "'${AUTH_CODE}'"
                }'
        #LOGOUT_RESULT=`curl -i -X POST -H "Content-Type:application/json" -d "${LOGOUT}" ${ZBX_ADDR} 2>/dev/null`;
        LOGOUT_RESULT=`curl -u : --negotiate -i -X POST -H "Content-Type:application/json" -d "${LOGOUT}" ${ZBX_ADDR} 2>/dev/null`;
        LOGOUT_RESULT="${LOGOUT_RESULT}";
        LOGOUT_RESULT=`echo ${LOGOUT_RESULT} | grep "true"`;
        if [ -n "${LOGOUT_RESULT}" ]
        then
                echo -e "${GREEN}Logout success.${DEFAULT}";
        else
                echo -e "${RED}Logout Fault!${DEFAULT}";
        fi
}


# Main 

case "${OPTION}" in
        -u)
                if [[ -z ${USERNAME} || -z ${PHONENUMBER} ]]
                then
                        USEAGE;
                        exit;
                fi
                KADMINPASSWORD;
                ADDUSERINKDC;
                ADDUSERINZBX;
                ;;
        -f)
                FILENAME="$2"
                #echo ${FILENAME};
                if [[ -n "${FILENAME}" && -e ${FILENAME} ]]
                then
                        KADMINPASSWORD;
                        cat ${FILENAME} | while read LINE
                                do
                                        USERNAME=`echo ${LINE} | awk '{print $1}'`;
                                        PHONENUMBER=`echo ${LINE} | awk '{print $2}'`;
                                        echo -e "Username is:${GREEN}${USERNAME}${DEFAULT}.";
                                        echo -e "Phonenumber is:${GREEN}${PHONENUMBER}${DEFAULT}";
                                        ADDUSERINKDC;
                                        ADDUSERINZBX;
                                done;
                else
                        USEAGE;
                fi
                ;;
        *)
                USEAGE;
                ;;
esac
