invest3repo=../../invest-natcap.invest-3
investdata=$invest3repo/test/invest-data
data_repos=../data_repos.txt
rm $data_repos  #clean start for each script run

function get_data_sha1 {
    # $1 is the branchname we're looking for
    grep $1 $data_repos | awk -F ' ' '{print $2}'
}

for branchname in `hg heads --template="{branch}\n" -R $invest3repo`
do
    hg up -C -r $branchname -R $invest3repo
    hg log -r . --template="$branchname {node} {rev}\n" -R $investdata >> $data_repos
done

# based on the sha1's recorded, figure out which should be committed in which order.
cat $data_repos

for branchname in `hg heads --template="{branch}\n" -R $invest3repo`
do
    hg up -C -r default -R .
    if [ "$branchname" = "default" ] || [ "$branchname" = "master" ] || [ "`echo $branchname | grep -o feature/`" = "feature/" ]
    then
        target_branch=$branchname
    else
        target_branch=feature/$branchname
    fi
    hg up -r $branchname -R $invest3repo
    hg branch $target_branch -R .
    ./get.sh
    hg commit -m "Copying branch $branchname to natcap/invest:$target_branch"
done
