# Create-FV2-Only-User
Proof of concept script to create a user account based on a smart card login for FileVault 2 login purposes. Inspired by Rich Trouton's blog post: https://derflounder.wordpress.com/2012/02/22/hiding-an-filevault-2-enabled-admin-user-with-casper/

Designed to be run as root by Casper after a successful PKINIT based smartcard login.

Note: Looks for a very specific user name format from the card. Will require modification for your own environment.
