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
#


echo "Apple Id :"
read appleid
echo "Password :"
read -s password

clear

path=$(pwd)

direc=$(mktemp -d)
cd $direc

# generate address
http="https://p24-buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/authenticate?attempt=0&why=signIn&guid=foo&password=$password&rmp=0&appleId=$appleid&createSession=true"


# get cookie
login_response=`curl -s -L --cookie-jar cookies.txt  -H "User-Agent: iTunes-iPhone/5.0" $http`

if `echo "${login_response}" | grep passwordToken &>/dev/null`; then
    # everything is ok
    true
else
    # oh oh your not recognize by server...
    echo "Something goes wrong ! Check your password and appleId. Exiting..."
    exit 1
fi;


# getting your purchase
## music
music_adress='https://se.itunes.apple.com/WebObjects/MZStoreElements.woa/wa/purchases?s=143442'
curl -s -L --cookie cookies.txt -H "User-Agent: iTunes-iPhone/5.0" "${music_adress}" > music_page

#awk -f $path/awk_script -v value=0 music_page > known
awk -v value=0 '{if ($0 ~ "script>"){value=0};if (value==1) {print $0}; if ($0 ~ "iTSP2MusicPurchasesData"){value=1}}' music_page > known

grep lockers known | sed 's/\(\[[0-9]*\)\(, \)\([0-9]*\]\)/\1-\3/g' | tr ',' '\n' | sed 's/"//g; s/://g; s/lockers//g; s/{//g; s/}//g; s/aIds/-/g; s/ //g' > tmp_song


for i in `cat tmp_song`; do
    # get the song adamid
    song=$(echo $i | sed -e 's/-.*//g')
    # get artist list
    artist_list=$(echo $i | sed -e 's/.*-\[//g; s/\]//g; s/-/ /g')
    i=0
    name=""
    for artist_name in `echo "$artist_list"`; do
        # get page of artist with song
        if (($i)); then
            name=$name" & "
        fi;     

        http="http://itunes.apple.com/fr/artist/id$artist_name?i=$song"
        curl -s -L --cookie-jar cookies.txt -H "User-Agent: iTunes-iPhone/5.0" $http > current_page
        tmp_artist_name=`grep artist-name current_page | sed -e 's/\(.*artist-name<\/key><string>\)\(.*\)\(.*<\/string>.*\)/\2/g' | head -n 1`
        new_http=$(grep $song current_page | sed -e '/url/!d;s/\(.*<key>url<\/key><string>\)\(http[^<]*\)\(<\/string>.*\)/\2/g')
        if [ ! -z $new_http ]; then
            rm current_page
            curl -s -L --cookie-jar cookies.txt -H "User-Agent: iTunes-iPhone/5.0" $new_http > current_page
            song_name=$(cat current_page | sed -e '/'"$song"'/!d; /preview-title/!d; s/\(.*preview-title="\)\(.*\)\(" preview.*\)/\2/1' | head -n 1)
            artist_name=$(cat current_page | sed -e '/'"$song"'/!d; /preview-artist/!d; s/\(.*preview-artist="\)\(.*\)\(" preview-title.*\)/\2/1' | head -n 1)
        else
            artist_name=$tmp_artist_name
            song_name="Error"
        fi
        name=$name$artist_name
        let i=i+1
    done
    if [ "$song_name" = "Error" ]; then
        song_name="**Unknown**"
    fi;
    echo $song_name" by "$name | recode h..utf8
done


cd ..
rm -rf $direc