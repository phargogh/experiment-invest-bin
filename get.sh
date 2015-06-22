#! /bin/bash
#
# Get package files from InVEST and copy them into invest.natcap.
#


invest_dir=../invest-natcap.invest-3
invest_pkgdir=$invest_dir/invest_natcap
natcap_dir=src/natcap
invest_dir=$natcap_dir/invest
for pkg_dir in `ls $invest_pkgdir`
do
    full_filepath=$invest_pkgdir/$pkg_dir
    if [ -d $full_filepath ]
    then
        cp -r $full_filepath $invest_dir
    else
        cp $full_filepath $invest_dir  # when it's just a python file
    fi
done

# remove cythonized/compiled files
echo "Removing compiled/cythonized files"
find $invest_dir -name "*.pyc" \
    -o -name "*.c" \
    -o -name "*.cpp" \
    -o -name "*.orig" \
    -o -name "*.so" | xargs rm

# remove any empty folders
echo "Removing any empty package folders"
for dirname in `ls $invest_dir`
do
    full_dirname=$invest_dir/$dirname
    if [ "`ls $full_dirname`" = "" ]  && [ -d "$full_dirname" ]
    then
        rm -r $full_dirname
    fi
done

# get the docs from invest-3
# The makefiles in the doc dir aren't strictly needed since we can do
# python setup.py build_sphinx and have the sphinx docs built, but I suppose
# they might be useful to someone.
echo "Copying docs"
cp -r $invest_dir/doc .
rm -r doc/build

# find/replace invest_natcap with natcap.invest
echo "Replacing 'invest_natcap' with 'natcap.invest'"
for py_file in `find doc natcap/invest -name "*.py" -o -name "*.json" -o -name "*.rst"`
do
    sed -i .bak 's/invest_natcap/natcap.invest/g' $py_file
    rm $py_file.bak
done

# expose the module's execute function by adding to the correct __init__ file
echo "Exposing entrypoints for models"
basedirname=$invest_dir
for name in `ls $basedirname`
do
    if [ -d "$basedirname/$name" ]
    then
        pkg_python_file=$basedirname/$name/$name.py
        pkg_init_file=$basedirname/$name/__init__.py
        if [ ! -e "$pkg_python_file" ]
        then
            echo "$pkg_python_file does not exist.  Manually expose the entry point for this package"
        else
            echo "from $name import execute" >> $pkg_init_file
            echo "__all__ = ['execute']" >> $pkg_init_file
        fi
    fi
done

exit 0

# find imports that are not in python's stdlib.
ENV=invest_test_env
virtualenv --no-setuptools --clear $ENV
source $ENV/bin/activate
which python
echo "Packages imported by python packages that might need to be installed"
for pkg_name in `grep -rh import\  $invest_dir | sort | uniq | grep -oEi '(^import [a-zA-Z0-9_]+)|(^from [a-zA-Z0-9_]+)' | grep -oE '[^ ]+$' | uniq`
do
    python -c "import $pkg_name" &> /dev/null

    # if the package does not import (exit code is nonzero), package might need to be installed.
    if [ "$?" -ne "0" ]
    then
        # If we can find a file by this name in the invest source tree, we won't need to install it to the system
        if [ ! -e "`find natcap/invest -name \"$pkg_name.py\" -o -name \"$pkg_name.pyx\"`" ]
        then
            echo $pkg_name
        fi
    fi
done
    

