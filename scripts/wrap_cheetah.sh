# In ubuntu 18.04, cheetah is available only for python 2
# In ubuntu 20.04, cheetah is available only for python 3
# This test check if the package Cheetah is available for the default verstion
# of python 3 or python 2
getPythonCheetah() {
    if python3 -c 'import Cheetah' 2> /dev/null; then 
        echo python3; 
    elif python2 -c 'import Cheetah' 2> /dev/null; then 
        echo python2;
    else
        echo "Python: package Cheetah not found in python2 and python3." >&2
        exit 1
    fi
}