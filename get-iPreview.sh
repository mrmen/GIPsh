#!/bin/bash
#
# Version : 1.0
# Current Date Release : 03-05-2012
# Initial Date Release : 03-05-2012
#
# Copyright (C) 2012 - Mrmen
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 3 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details at
# http://www.gnu.org/copyleft/gpl.html
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <http://www.gnu.org/licenses>.
#



function usage (){
    echo "Usage of "$0
    echo ""
    echo $0" name-of-artist"
    echo ""
    echo "should return a link to acces your artist on iTunes"
    exit 0
}



if (($#!=1)); then 
    echo "not enough arguments"
    usage
fi;

artist=`echo $1 | sed -e 's/ /+/g'`

address="http://ax.phobos.apple.com.edgesuite.net/WebObjects/MZStoreServices.woa/wa/wsSearch?term=""${artist}""&limit=3&entity=musicArtist"

DIR=`mktemp -d`

cd $DIR

wget -O test $address &>/dev/null

# in order to define the artist number
nb_artist=0
cat test | awk 'BEGIN{FS=","}{if (tolower($0)  ~ "artistname") {print $3}}' | sed 's/\(.*:"\)\(.*\)\("\)/\2/' > artist 


# test if exact artist is found
to_be_executed=`awk -v value=1 '{if (tolower($0)==tolower("'"$1"'")){print "nb_artist="value}; value++}' artist`
eval $to_be_executed

if (($nb_artist==0)); then
    echo "Who is your artist :"
    cat artist | awk -v value=1 '{print value" - "$0;value++}'
    echo "Choose your artist :"
    read nb_artist
fi;


clear
if (($nb_artist!=0))
    then
    address=`awk -v compteur=1 'BEGIN{FS=","}{if (tolower($0)  ~ "artistname") {if (compteur=="'"$nb_artist"'") {print $4; exit} else {compteur++}}}' test | sed 's/\(.*:"\)\(.*\)\("\)/\2/g; s/\/us\//\/fr\//g'`
fi

# now get the page of the artist and find how many they are :
# we want all songs

wget -O tmp_page  $address &>/dev/null
nb_of_page=`cat tmp_page | sed -e '/list paginate/!d; /trackPage/!d; s/\(.*Page">\)\([0-9]*\)\(<\/a.*\)/\2/'`

#getting all song name and putting into a file

if !(($nb_of_page)); then
    nb_of_page=1
fi

for i in `seq 1 1 $nb_of_page`; do
    wget -O tmp_song "$address""?trackPage="$i"#trackPage" &>/dev/null
    cat tmp_song >> all_song_info
    cat tmp_song | sed '/song music/!d; /preview-title/!d; s/\(.*preview-title="\)\(.*\)\(" pr.*\)/\2/g' | recode h..utf8 >> song_list
done

awk -v value=1 '{print value" -"$0; value++}' song_list

# choose your song
echo "now chosse your song number :"
echo "=============================="

read list_song_number

percent=$(echo $list_song_number | wc -w)
symbole_len=$(echo "100/"$percent | bc)
symbole=$(eval printf '%.0s.' {1..$symbole_len})

clear 

echo "Downloading..."
echo -n "["
tmp_symb=$(printf '%.0s ' {1..100})
echo -n $tmp_symb
echo -n "]"
printf '%.0s\r' {1..100}


for song_number in $list_song_number; do
    if [ ! "$(echo $song_number | grep "^[ [:digit:] ]*$")" ] 
    then 
	echo "It's not an int. Exiting..."
	exit 1
    else
	if (($song_number>`cat song_list | wc -l `))
	then
	    echo "Number is too big. Exiting..."
	    exit 1
	fi
    fi


    song_name=`awk -v value=1 '{if (value=="'"$song_number"'"){print $0; exit};value++}' song_list | recode utf8..h`
    
    song_name_utf8=`echo "${song_name}" | recode h..utf8`
    
    song_address=`cat all_song_info | awk '{ if ($0 ~ "'"$song_name"'") { if ($0 ~ "preview-duration") {print $0; exit}}}' | sed -e 's/\(.*audio-preview-url="\)\(http:.*m4a\)\(" .*\)/\2/1'`
    
    echo -n $symbole
    
    cd /tmp

    wget -O "${song_name_utf8}".m4a "${song_address}" &>/dev/null

    echo "preview saved as "${song_name_utf8}.m4a" in /tmp" >> $DIR/song_dl
    
    cd $DIR
done

echo ""
cat song_dl
cd 
rm -rf $DIR
