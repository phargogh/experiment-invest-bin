if [ -e invest-sample-data ]
then
    rm -r invest-sample-data
fi
svn checkout http://ncp-yamato.stanford.edu/svn/invest-sample-data

hg_data=~/workspace/invest-natcap.invest-3/test/invest-data
for name in `ls ${hg_data}`
do 
    if [ "$name" != "test" ] && [ "$name" != "invest-sample-data" ]
    then
        echo $name
        cp -r $hg_data/$name invest-sample-data/$name
    fi
done

# Ideally, we'll want to clean up our data files and only have the ones that we need.
