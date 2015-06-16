out_file=HISTORY.rst
rm $out_file

hg revert --all -R src/invest-natcap.default
find src/invest-natcap.default -name "*.orig" | xargs rm

for file in `ls src/invest-natcap.default/docs/release_notes/ | sort -r`
do
    full_filepath=src/invest-natcap.default/docs/release_notes/$file
    echo $file | grep -o InVEST_.*.txt | sed 's/_/ /g' | sed 's/.txt//g' >> $out_file
    echo "=====================" >> $out_file
    dos2unix -1252 $full_filepath  # assume the file is written in windows codepage 1252.
    cat $full_filepath >> $out_file
    echo  >> $out_file
    echo  >> $out_file
done
