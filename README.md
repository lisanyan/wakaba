# Wakaba 3.0.9 + mods by Alice

## What this includes
* Multiple file posting
* Thread locking, autosage
* JSON API
* Post search
* Reports
* Expiring bans
* IPv6 Support (currently no subnet banning)
* Imageboard-like admin panel
* File metadata (mime type, etc)
* Sexy file sizes
* Optional sage checkbox instead of emails
* Banner rotation
* Mod/Admin accounts (set in lib/moders.pl)
* DNSBL Support (useful for banning tor nodes etc)

## What this doesn't include
* Stickies.
* IPv4 CIDR was removed because it only worked on 32-bit systems. Use full
  masks (i.e. `255.255.255.0`) instead.
* IPv6 range ban/deleting doesn't work because 128-bit integers aren't
  present in MySQL.
* The *Gurochan* style was removed because it's ***ugly***.

## Bugs/what is untested
* Load balancing (probs broken)
* SQLite support is probably broken.
* Perl <5.10 should work, but this is completely untested.

## How to use

### Standard installation
1. Copy all files to the web server.
2. Create new board folder
3. Copy files from "board" to your new board folder
4. Make sure `wakaba.pl`, and `captcha.pl` have the executable
   (+x) bit.
5. Hit `wakaba.pl` in your browser.

###Upgrading from a standard Wakaba
1. Replace all the board files with new ones.
2. Create new board folder
3. Copy files from "board" to your new board folder
4. Move your src/ and thumb/ folders into board folder that you've created
5. Edit config
6. Create `migrate_sql` file in your new board folder
7. Hit `/wakaba.pl?board=<my board>` in your browser to upgrade db tables.
8. Remove `migrate_sql` file if migration was successful
9. Log in and rebuild caches.
10.  Do the same again for other boards
