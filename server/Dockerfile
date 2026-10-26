# Our own "LinuxGSM": SteamCMD and the mods are in the image; CS 1.6 itself is downloaded on first start,
# into the /hlds volume. No game file from Valve is in the image (only SteamCMD, which downloads it).
# ReHLDS replaces Valve's engine, ReGameDLL its game code (cs.so); ReAPI gives our plugins access to both.
# ReDeathmatch makes it a "Respawn" server: you respawn at once, rounds never end.
FROM debian:trixie-slim

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl lib32gcc-s1 lib32stdc++6 libc6:i386 unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*

# Each version comes with its SHA-256. Renovate proposes new versions (renovate.json); the checksum is updated by
# hand: curl -sL <archive URL> | sha256sum
# renovate: depName=rehlds/ReHLDS
ARG REHLDS=3.15.0.896
ARG REHLDS_SHA256=997baeb7ef3842dab3e034d82dc651ebfe560c23b158adce660a6b97976b4e2b
# renovate: depName=rehlds/ReGameDLL_CS
ARG REGAMEDLL=5.30.0.814
ARG REGAMEDLL_SHA256=457f5c96a4d10280fcad47f106cbd5be86363a47df1ccab91c514e9d1bc6fd18
# renovate: depName=rehlds/Metamod-R
ARG METAMOD=1.3.0.149
ARG METAMOD_SHA256=ede7f59c4e0220afe8c02aa348a130cce527f87d36ffdb674e37a501ce57be94
# renovate: depName=rehlds/ReAPI
ARG REAPI=5.29.0.358
ARG REAPI_SHA256=f33a7435540bea8706db3fa948e51a85b511f5b18c383b97402a204dc5419195
# A new War3FT release may bundle another AMX Mod X build: check the file name in the download line below too.
# renovate: depName=wc3mods/war3ft
ARG WAR3FT=v3.0.1
ARG WAR3FT_SHA256=5b1da0e8c1a44666b971c216f73f2761ee18aa0cf8ee91de37e2e9062f1f60f0
# renovate: depName=ReDeathmatch/ReDeathmatch_AMXX
ARG REDM=1.0.0-b11
ARG REDM_SHA256=2b6a2c5abee9198500c6a6362fcc0e55784dd4fc387365565ab82d8ecaa49abe
# renovate: depName=yapb/yapb
ARG YAPB=4.4.957
ARG YAPB_SHA256=8c095ac89b9b2ccc70a66a71d608e1a570b5268c57c6083ced8c06161533a4b1

# /opt/mods has the same layout as /hlds: the entrypoint copies it over the game at every start.
# A wrong checksum stops the build: a modified archive is never installed.
RUN set -eu; cd /tmp; \
    download() { curl -fsSL -o "$1" "$2"; echo "$3  $1" | sha256sum -c -; }; \
    download rehlds.zip https://github.com/rehlds/ReHLDS/releases/download/$REHLDS/rehlds-bin-$REHLDS.zip $REHLDS_SHA256; \
    download regamedll.zip https://github.com/rehlds/ReGameDLL_CS/releases/download/$REGAMEDLL/regamedll-bin-$REGAMEDLL.zip $REGAMEDLL_SHA256; \
    download metamod.zip https://github.com/rehlds/Metamod-R/releases/download/$METAMOD/metamod-bin-$METAMOD.zip $METAMOD_SHA256; \
    download reapi.zip https://github.com/rehlds/ReAPI/releases/download/$REAPI/reapi-bin-$REAPI.zip $REAPI_SHA256; \
    download war3ft.zip https://github.com/wc3mods/war3ft/releases/download/$WAR3FT/war3ft-$WAR3FT-cstrike-amxmodx-1.10.0-git5467.zip $WAR3FT_SHA256; \
    download redm.zip https://github.com/ReDeathmatch/ReDeathmatch_AMXX/releases/download/$REDM/ReDeathmatch-$REDM.zip $REDM_SHA256; \
    download yapb.tar.xz https://github.com/yapb/yapb/releases/download/$YAPB/yapb-$YAPB-linux.tar.xz $YAPB_SHA256; \
    mkdir -p /opt/mods/cstrike; \
    unzip -q rehlds.zip 'bin/linux32/*' -d rehlds && cp -R rehlds/bin/linux32/. /opt/mods/; \
    unzip -q war3ft.zip -d /opt/mods/cstrike; \
    unzip -qo metamod.zip 'addons/*' -d /opt/mods/cstrike; \
    unzip -q regamedll.zip 'bin/linux32/*' -d regamedll && cp -R regamedll/bin/linux32/cstrike/. /opt/mods/cstrike/; \
    unzip -qo reapi.zip 'addons/amxmodx/modules/*.so' 'addons/amxmodx/scripting/include/*' -d /opt/mods/cstrike; \
    unzip -qo redm.zip 'cstrike/addons/*' -d /tmp/redm && cp -R /tmp/redm/cstrike/. /opt/mods/cstrike/; \
    tar -xJf yapb.tar.xz -C /opt/mods/cstrike; \
    rm -rf /tmp/*

# The settings, applied to the original files (War3FT has no license: we do not republish its files).
# Each change is checked: if an upstream file changes, the build stops instead of silently ignoring it.
# wc3_xp_multiplier 0.5: half the XP for each level, so new players reach their ultimate (level 6) twice as fast.
# wc3_start_level 3: a race never played starts at level 3 (3 skills at once); the ultimate is still to earn.
# wc3_psychostats 0: no log line at each skill used, for PsychoStats, which we do not use.
# yb_difficulty_min 0, max 2: each bot gets a random level from Newbie to Normal, a mix like real players.
# YaPB's automatic mode is off: it balances each bot against the others, and pushes them up to Expert.
# War3FT and ReDeathmatch run without AMX Mod X's debug mode (slower). No AMX Mod X ads (scrollmsg, imessage): our own messages are in messages.txt.
# ReDeathmatch's rules (gamemode_deathmatch.json) are made for free-for-all: here, teams (War3 has team skills, at
# most 2 players apart), 800 of starting money (the War3 shops cost money), and respawns in the team's base
# (ReDeathmatch only has spawn points for 3 of our maps). Rounds never end ("1"): its "bcdefg" would end one at
# each mp_roundtime (5 minutes). The bots play team deathmatch (yb_csdm_mode 1), never camp, and get the weapons
# players use (AK-47 or M4A1; Deagle, USP or Glock), not ReDeathmatch's (Famas, Galil, P228, Elite). Their names
# start with "[AI] ": the AI shows in the scoreboard. No avatars: YaPB borrows them from real Steam accounts.
# Spawn protection (ReGameDLL's game.cfg): 3 seconds without damage after a respawn, lost at the first shot (not when
# moving: "2"). ReDeathmatch tints the protected players in their team's color. A map lasts 30 minutes: game.cfg is
# read after server.cfg at each map, so its mp_timelimit (20) is the one that counts. game.cfg's lines end with \r.
# CS's ranking (/rank, /top15) counts the fights with bots, most of the fights here. All bots share one row in it
# (SteamID "BOT"), which the stats page leaves out.
RUN set -eu; cd /opt/mods/cstrike; \
    sed -i 's|^gamedll_linux .*|gamedll_linux "addons/metamod/metamod_i386.so"|' liblist.gam; \
    printf '\nlinux addons/yapb/bin/yapb.so\n' >> addons/metamod/plugins.ini; \
    sed -i 's/^;sqlite/sqlite/' addons/amxmodx/configs/modules.ini; \
    sed -i 's/^csstats_rankbots 0$/csstats_rankbots 1/' addons/amxmodx/configs/amxx.cfg; \
    sed -i -e 's/^mp_respawn_immunitytime "0"\r$/mp_respawn_immunitytime "3"/' \
      -e 's/^mp_timelimit "20"\r$/mp_timelimit "30"/' \
      -e 's/^mp_respawn_immunity_force_unset "1"\r$/mp_respawn_immunity_force_unset "2"/' game.cfg; \
    sed -i -e 's/^war3ft.amxx debug$/war3ft.amxx/' -e 's/^scrollmsg.amxx/;scrollmsg.amxx/' \
      -e 's/^imessage.amxx/;imessage.amxx/' addons/amxmodx/configs/plugins.ini; \
    sed -i 's/[[:space:]]*debug$//' addons/amxmodx/configs/plugins-redm.ini; \
    sed -i -e 's/"mp_freeforall": "1"/"mp_freeforall": "0"/' \
      -e 's/"mp_startmoney": "0"/"mp_startmoney": "800"/' \
      -e 's/"mp_limitteams": "0"/"mp_limitteams": "2"/' \
      -e 's/"mp_round_infinite": "bcdefg"/"mp_round_infinite": "1"/' \
      -e 's/"redm_randomspawn": "1"/"redm_randomspawn": "0"/' \
      -e '/"botEquip": {/,/^        }/{s/"weapon_famas"/"weapon_ak47"/; s/"weapon_galil"/"weapon_m4a1"/; s/"weapon_p228"/"weapon_usp"/; s/"weapon_elite"/"weapon_glock18"/}' \
      addons/amxmodx/configs/redm/gamemode_deathmatch.json; \
    sed -i 's/^wc3_save_xp\t*0/wc3_save_xp\t\t1/' addons/amxmodx/configs/war3ft/war3FT.cfg; \
    sed -i 's/^wc3_xp_multiplier\t*1\.0/wc3_xp_multiplier\t0.5/' addons/amxmodx/configs/war3ft/war3FT.cfg; \
    sed -i 's/^wc3_start_level\t*0\t/wc3_start_level\t\t3\t/' addons/amxmodx/configs/war3ft/war3FT.cfg; \
    sed -i 's/^wc3_psychostats\t*1\t/wc3_psychostats\t\t0\t/' addons/amxmodx/configs/war3ft/war3FT.cfg; \
    sed -i -e 's/^yb_quota "9"/yb_quota "10"/' -e 's/^yb_quota_mode "normal"/yb_quota_mode "fill"/' \
      -e 's/^yb_chat "1"/yb_chat "0"/' -e 's/^yb_radio_mode "2"/yb_radio_mode "0"/' \
      -e 's/^yb_csdm_mode "0"/yb_csdm_mode "1"/' -e 's/^yb_difficulty_min "-1"/yb_difficulty_min "0"/' \
      -e 's/^yb_difficulty_max "-1"/yb_difficulty_max "2"/' \
      -e 's/^yb_camping_allowed "1"/yb_camping_allowed "0"/' -e 's/^yb_name_prefix ""/yb_name_prefix "[AI] "/' \
      -e 's/^yb_show_avatars "1"/yb_show_avatars "0"/' \
      addons/yapb/conf/yapb.cfg; \
    grep -q '^gamedll_linux "addons/metamod/metamod_i386.so"' liblist.gam; \
    grep -q '^sqlite' addons/amxmodx/configs/modules.ini; \
    grep -qx 'csstats_rankbots 1' addons/amxmodx/configs/amxx.cfg; \
    grep -qx 'mp_respawn_immunitytime "3"' game.cfg; \
    grep -qx 'mp_respawn_immunity_force_unset "2"' game.cfg; \
    grep -qx 'mp_timelimit "30"' game.cfg; \
    grep -qx 'war3ft.amxx' addons/amxmodx/configs/plugins.ini; \
    ! grep -qE '^(scrollmsg|imessage).amxx' addons/amxmodx/configs/plugins.ini || exit 1; \
    grep -q '^ReDeathmatch.amxx$' addons/amxmodx/configs/plugins-redm.ini; \
    ! grep -q 'debug' addons/amxmodx/configs/plugins-redm.ini || exit 1; \
    for line in '"mp_freeforall": "0"' '"mp_startmoney": "800"' '"mp_limitteams": "2"' \
                '"mp_round_infinite": "1"' '"redm_randomspawn": "0"'; do \
      grep -qF "$line" addons/amxmodx/configs/redm/gamemode_deathmatch.json; \
    done; \
    grep -A9 '"botEquip"' addons/amxmodx/configs/redm/gamemode_deathmatch.json > /tmp/bot_equip; \
    for weapon in ak47 m4a1 deagle usp glock18; do grep -q "\"weapon_$weapon\"" /tmp/bot_equip; done; \
    ! grep -qE 'famas|galil|p228|elite' /tmp/bot_equip || exit 1; \
    grep -qP '^wc3_save_xp\t+1' addons/amxmodx/configs/war3ft/war3FT.cfg; \
    grep -qP '^wc3_xp_multiplier\t+0\.5' addons/amxmodx/configs/war3ft/war3FT.cfg; \
    grep -qP '^wc3_start_level\t+3\t' addons/amxmodx/configs/war3ft/war3FT.cfg; \
    grep -qP '^wc3_psychostats\t+0\t' addons/amxmodx/configs/war3ft/war3FT.cfg; \
    for line in 'yb_quota "10"' 'yb_quota_mode "fill"' 'yb_chat "0"' 'yb_radio_mode "0"' \
                'yb_csdm_mode "1"' 'yb_difficulty_min "0"' 'yb_difficulty_max "2"' 'yb_camping_allowed "0"' \
                'yb_name_prefix "[AI] "' 'yb_show_avatars "0"'; do \
      grep -qxF "$line" addons/yapb/conf/yapb.cfg; \
    done

# Our bots' names (bots.txt, before the "|"), in place of YaPB's: short and easy to type, to talk to them (YaPB's list
# also has a racial slur).
COPY bots.txt /tmp/bots.txt
RUN set -eu; names=/opt/mods/cstrike/addons/yapb/conf/lang/en_names.cfg; \
    grep -v '^;' /tmp/bots.txt | cut -d'|' -f1 | sed 's/ *$//' | grep . > "$names"; \
    [ "$(wc -l < "$names")" -ge 10 ]; \
    rm /tmp/bots.txt

# Our AMX Mod X plugins, compiled with the compiler from the War3FT package.
COPY plugins/ /opt/mods/cstrike/addons/amxmodx/scripting/cs-war3-ai/
RUN set -eu; cd /opt/mods/cstrike/addons/amxmodx/scripting; \
    for source in cs-war3-ai/*.sma; do \
      name=$(basename "$source" .sma); \
      ./amxxpc "$source" -o"../plugins/$name.amxx"; \
      echo "$name.amxx" >> ../configs/plugins.ini; \
    done

COPY server.cfg mapcycle.txt /opt/mods/cstrike/
# The announcer's voices (CC-BY 3.0, see sound/announcer/CREDITS.txt). Players download them from our Caddy (FastDL).
COPY sound/ /opt/mods/cstrike/sound/
# The same map list for the end-of-map vote (mapchooser) and rtv (rtv.sma).
COPY mapcycle.txt /opt/mods/cstrike/addons/amxmodx/configs/maps.ini
COPY messages.txt /opt/mods/cstrike/addons/amxmodx/configs/messages.txt

# Readable by steam; its copy in /hlds writable (YaPB and AMX Mod X write there).
RUN chmod -R a+rX,u+w /opt/mods

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

# The database's folder exists from the start: Docker copies it into the new volume, and the stats container can
# mount it before CS 1.6 is installed.
RUN useradd -m -u 1000 steam && mkdir -p /hlds/cstrike/addons/amxmodx/data/sqlite3 && chown -R steam:steam /hlds
USER steam

# SteamCMD updates itself on first launch: done here once and for all.
# The sdk32 link: without it, HLDS does not find steamclient.so and refuses Steam players.
RUN mkdir -p ~/steamcmd ~/.steam/sdk32 \
 && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar xz -C ~/steamcmd \
 && ~/steamcmd/steamcmd.sh +quit \
 && ln -s ~/steamcmd/linux32/steamclient.so ~/.steam/sdk32/steamclient.so

VOLUME /hlds
WORKDIR /hlds
EXPOSE 27015/udp
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
