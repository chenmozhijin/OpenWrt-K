#!/bin/sh
curl https://cf.trackerslist.com/all_aria2.txt||exit 1
export bt_tracker="$(curl -s https://cf.trackerslist.com/all_aria2.txt)"||exit 1
uci set aria2.main.bt_tracker=$bt_tracker||exit 1
uci commit aria2
/etc/init.d/aria2 restart
mkdir -p /tmp/cmzj/update||exit 1
cd /tmp/cmzj/update||exit 1
rm -rf /tmp/cmzj/update/*||exit 1
curl https://raw.githubusercontent.com/YW5vbnltb3Vz/domain-list-community/release/gfwlist.txt -o /tmp/cmzj/update/base64_YW5vbnltb3Vz.txt||exit 1
curl https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/gfw.txt -o /tmp/cmzj/update/Loyalsoldier.txt||exit 1
curl https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt -o /tmp/cmzj/update/base64_gfwlist.txt||exit 1
curl https://raw.githubusercontent.com/Loukky/gfwlist-by-loukky/master/gfwlist.txt -o /tmp/cmzj/update/base64_Loukky.txt||exit 1
base64 -d /tmp/cmzj/update/base64_YW5vbnltb3Vz.txt > /tmp/cmzj/update/YW5vbnltb3Vz.txt||exit 1
base64 -d /tmp/cmzj/update/base64_gfwlist.txt > /tmp/cmzj/update/gfwlist.txt||exit 1
base64 -d /tmp/cmzj/update/base64_Loukky.txt > /tmp/cmzj/update/Loukky.txt||exit 1
sed -e '/^!/d' -e '/^\\/d' -e '/^@/d' -e 's/|//g' -e '/^http:\/\//d' -e '/^https:\/\//d' -e '/\//d' -e 's/^\.//g' -e '/\./!d' -e '/ /d' -e '/\*/d' -e '/%/d' -e '/^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/d' /tmp/cmzj/update/YW5vbnltb3Vz.txt>> /tmp/cmzj/update/gfwlist_chen||exit 1
sed -e '/^!/d' -e '/^\\/d' -e '/^@/d' -e 's/|//g' -e '/^http:\/\//d' -e '/^https:\/\//d' -e '/\//d' -e 's/^\.//g' -e '/\./!d' -e '/ /d' -e '/\*/d' -e '/%/d' -e '/^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/d' /tmp/cmzj/update/Loyalsoldier.txt>> /tmp/cmzj/update/gfwlist_chen||exit 1
sed -e '/^!/d' -e '/^\\/d' -e '/^@/d' -e 's/|//g' -e '/^http:\/\//d' -e '/^https:\/\//d' -e '/\//d' -e 's/^\.//g' -e '/\./!d' -e '/ /d' -e '/\*/d' -e '/%/d' -e '/^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/d' /tmp/cmzj/update/gfwlist.txt>> /tmp/cmzj/update/gfwlist_chen||exit 1
sed -e '/^!/d' -e '/^\\/d' -e '/^@/d' -e 's/|//g' -e '/^http:\/\//d' -e '/^https:\/\//d' -e '/\//d' -e 's/^\.//g' -e '/\./!d' -e '/ /d' -e '/\*/d' -e '/%/d' -e '/^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/d' /tmp/cmzj/update/Loukky.txt>> /tmp/cmzj/update/gfwlist_chen||exit 1
sort /tmp/cmzj/update/gfwlist_chen | uniq > /tmp/cmzj/update/gfwlist||exit 1
echo "127.0.0.1:6053" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "# Steam++ Start" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/steam-chat.com/steamcdn-a.akamaihd.net/cdn.akamai.steamstatic.com/community.akamai.steamstatic.com/avatars.akamai.steamstatic.com/media.steampowered.com/store.steampowered.com/api.steampowered.com/help.steampowered.com/steamcommunity.com/www.steamcommunity.com/support.discord.com/safety.discord.com/support-dev.discord.com/dl.discordapp.net/discordapp.com/support.discordapp.com/url9177.discordapp.com/canary-api.discordapp.com/cdn-ptb.discordapp.com/ptb.discordapp.com/status.discordapp.com/cdn-canary.discordapp.com/cdn.discordapp.com/streamkit.discordapp.com/i18n.discordapp.com/url9624.discordapp.com/url7195.discordapp.com/merch.discordapp.com/printer.discordapp.com/canary.discordapp.com/apps.discordapp.com/pax.discordapp.com/media.discordapp.net/images-ext-2.discordapp.net/images-ext-1.discordapp.net/images-2.discordapp.net/images-1.discordapp.net/discord.com/click.discord.com/status.discord.com/streamkit.discord.com/ptb.discord.com/i18n.discord.com/pax.discord.com/printer.discord.com/canary.discord.com/feedback.discord.com/updates.discord.com/irc-ws.chat.twitch.tv/irc-ws-r.chat.twitch.tv/passport.twitch.tv/abs.hls.ttvnw.net/video-edge-646949.pdx01.abs.hls.ttvnw.net/id-cdn.twitch.tv/id.twitch.tv/pubsub-edge.twitch.tv/supervisor.ext-twitch.tv/vod-secure.twitch.tv/music.twitch.tv/twitch.tv/www.twitch.tv/m.twitch.tv/app.twitch.tv/badges.twitch.tv/blog.twitch.tv/inspector.twitch.tv/stream.twitch.tv/dev.twitch.tv/clips.twitch.tv/gql.twitch.tv/vod-storyboards.twitch.tv/trowel.twitch.tv/countess.twitch.tv/extension-files.twitch.tv/vod-metro.twitch.tv/pubster.twitch.tv/help.twitch.tv/link.twitch.tv/player.twitch.tv/api.twitch.tv/cvp.twitch.tv/clips-media-assets2.twitch.tv/client-event-reporter.twitch.tv/gds-vhs-drops-campaign-images.twitch.tv/us-west-2.uploads-regional.twitch.tv/assets.help.twitch.tv/discuss.dev.twitch.tv/dashboard.twitch.tv/origin-a.akamaihd.net/store.ubi.com/static3.cdn.ubi.com/gravatar.com/secure.gravatar.com/www.gravatar.com/themes.googleusercontent.com/maxcdn.bootstrapcdn.com/ajax.googleapis.com/fonts.googleapis.com/fonts.gstatic.com/hcaptcha.com/assets.hcaptcha.com/imgs.hcaptcha.com/www.hcaptcha.com/docs.hcaptcha.com/js.hcaptcha.com/newassets.hcaptcha.com/google.com/www.google.com/client-api.arkoselabs.com/epic-games-api.arkoselabs.com/cdn.arkoselabs.com/prod-ireland.arkoselabs.com/api.github.com/gist.github.com/raw.github.com/githubusercontent.com/raw.githubusercontent.com/camo.githubusercontent.com/cloud.githubusercontent.com/avatars.githubusercontent.com/avatars0.githubusercontent.com/avatars1.githubusercontent.com/avatars2.githubusercontent.com/avatars3.githubusercontent.com/user-images.githubusercontent.com/github.io/www.github.io/githubapp.com/github.com/pages.github.com/nexusmods.com/www.nexusmods.com/staticdelivery.nexusmods.com/cf-files.nexusmods.com/staticstats.nexusmods.com/users.nexusmods.com/files.nexus-cdn.com/premium-files.nexus-cdn.com/supporter-files.nexus-cdn.com/storage.live.com/skyapi.onedrive.live.com/onedrive.live.com/onedrive.live/mega.co.nz/g.cdn1.mega.co.nz/www.mega.co.nz/userstroage.mega.co.nz/g.api.mega.co.nz/mega.nz/mega.io/aem.dropbox.com/dl.dropboxusercontent.com/uc07aaf207f16a978a3dbc24a1c9.dl.dropboxusercontent.com/uc87442e427766fe8cf2a7a07827.dl.dropboxusercontent.com/uc957f785cc03b9b273234fd24f9.dl.dropboxusercontent.com/ucc541451e9df780e40777d477eb.dl.dropboxusercontent.com/ucb277f9a438d6b3f4ea2147ac26.dl.dropboxusercontent.com/uc4b4b602d4b01e27782f92ce984.dl.dropboxusercontent.com/uc9c83355d6aa8bc75f7f597c7d6.dl.dropboxusercontent.com/ucaf37cba09486e69c215bdfe2e2.dl.dropboxusercontent.com/uca3a40eb53259715309022eb9fd.dl.dropboxusercontent.com/dropbox.com/www.dropbox.com/pinterest.com/www.pinterest.com/pinimg.com/sm.pinimg.com/s.pinimg.com/i.pinimg.com/artstation.com/www.artstation.com/cdn-learning.artstation.com/cdna.artstation.com/cdn.artstation.com/cdnb.artstation.com/aleksi.artstation.com/aroll.artstation.com/dya.artstation.com/yourihoek.artstation.com/rishablue.artstation.com/ww.artstation.com/magazine.artstation.com/v2ex.com/www.v2ex.com/cdn.v2ex.com/imgur.com/i.imgur.com/s.imgur.com/i.stack.imgur.com/m.imgur.com/api.imgur.com/p.imgur.com/www.imgur.com/fufufu23.imgur.com/thepoy.imgur.com/blog.imgur.com/cellcow.imgur.com/t.imgur.com/sketch.pixiv.net/pixivsketch.net/www.pixivsketch.net/pximg.net/i.pximg.net/s.pximg.net/img-sketch.pximg.net/source.pximg.net/booth.pximg.net/i-f.pximg.net/imp.pximg.net/public-img-comic.pximg.net/www.pixiv.net/touch.pixiv.net/source.pixiv.net/accounts.pixiv.net/imgaz.pixiv.net/app-api.pixiv.net/oauth.secure.pixiv.net/dic.pixiv.net/comic.pixiv.net/factory.pixiv.net/g-client-proxy.pixiv.net/payment.pixiv.net/sensei.pixiv.net/novel.pixiv.net/ssl.pixiv.net/times.pixiv.net/recruit.pixiv.net/pixiv.net/p2.pixiv.net/matsuri.pixiv.net/m.pixiv.net/iracon.pixiv.net/inside.pixiv.net/i1.pixiv.net/help.pixiv.net/goods.pixiv.net/genepixiv.pr.pixiv.net/festa.pixiv.net/en.dic.pixiv.net/dev.pixiv.net/chat.pixiv.net/blog.pixiv.net/embed.pixiv.net/comic-api.pixiv.net/pay.pixiv.net/pixon.ads-pixiv.net/link.pixiv.net/in.appcenter.ms/appcenter.ms/local.steampp.net/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "# Steam++ End" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/*.hk/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/*.in/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/*.io/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/*.jp/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/*.mo/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/*.ru/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/*.th/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/*.tw/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/*.uk/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/*.uk/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/*.cn/]127.0.0.1:6053" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/github.com/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/*.github.com/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "#" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "#" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "#bbs" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/bbs.sumisora.org/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/www.tsdm39.net/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "[/kait.cc/]127.0.0.1:5335" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
echo "#gfwlist" >>/tmp/cmzj/update/AdGuardHomednslist||exit 1
sed -e 's/^/[\//g' -e 's/$/\/]127.0.0.1:5335/g' /tmp/cmzj/update/gfwlist >> /tmp/cmzj/update/AdGuardHomednslist||exit 1
cat /tmp/cmzj/update/AdGuardHomednslist > /etc/AdGuardHome-dnslist"(by cmzj)".yaml||exit 1
/etc/init.d/AdGuardHome restart
echo "complete"
exit 0