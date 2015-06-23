invest3repo=../../invest-natcap.invest-3
investdata=$invest3repo/test/invest-data
data_repos=../data_repos.txt
svn_data_commits=../svn_data_revs.txt
rm $svn_data_commits  # clean start for each script run
rm $data_repos  #clean start for each script run

function get_data_sha1 {
# get the hg sha1 by either branchname or revset number.
    # $1 is the branchname we're looking for
    if [ "`echo $1 | grep [0-9]\\+`" != "" ]
    then
        # it's a rev.
        grep $1$ $data_repos | awk -F ' ' '{print $2}'
    else
        # it's a branch
        grep $1 $data_repos | awk -F ' ' '{print $2}'
    fi
}

function get_svn_commit_by_sha1 {
# get the SVN commit number by the hg data sha1
    rev=`grep $1 $data_repos | head -n 1 | awk -F ' ' '{print $3}'`
    output=`grep $rev$ $svn_data_commits | awk -F ' ' '{print $1}'`
    echo $output
}

for branchname in `hg heads --template="{branch}\n" -R $invest3repo`
do
    hg up -q -C -r $branchname -R $invest3repo
    hg log -r . --template="$branchname {node} {rev}\n" -R $investdata >> $data_repos
done

# based on the sha1's recorded, figure out which should be committed in which order.
svn_commit=-1
for data_rev in `cat $data_repos | awk -F ' ' '{print $3}' | sort | uniq`
do
    svn_commit=$((svn_commit + 1))
    echo "$svn_commit $data_rev" >> $svn_data_commits
    # COPY DATA AND SVN COMMIT HERE
done

for branchname in `hg heads --template="{branch}\n" -R $invest3repo`
do
    hg up -q -C -r default -R .
    if [ "$branchname" = "default" ] || [ "$branchname" = "master" ] || [ "`echo $branchname | grep -o feature/`" = "feature/" ]
    then
        target_branch=$branchname
    else
        target_branch=feature/$branchname
    fi
    hg up -q -r $branchname -R $invest3repo
    #hg branch $target_branch -R .
    #./get.sh
    #hg commit -m "Copying branch $branchname to natcap/invest:$target_branch"
    data_sha1=`get_data_sha1 $branchname` 
    echo 'SHA1' $data_sha1
    svn_version=`get_svn_commit_by_sha1 $data_sha1`
    echo 'SVN' $svn_version
    sed -i "" "s/\"0\"/\"$svn_version\"/g" versions.json
done
