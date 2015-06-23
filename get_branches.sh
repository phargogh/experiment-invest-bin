invest3repo=../../invest-natcap.invest-3

for branchname in `hg heads --template="{branch}\n" -R $invest3repo`
do
    hg up -C -r default -R .
    if [ "$branchname" = "default" ] || [ "$branchname" = "master" ] || [ "`echo $branchname | grep -o feature/`" = "feature/" ]
    then
        target_branch=$branchname
    else
        target_branch=feature/$branchname
    fi
    hg up -r $target_branch -R $invest3repo
    hg branch $target_branch -R .
    ./get.sh
    hg commit -m "Copying branch $branchname to natcap/invest:$target_branch"
done
