Automated WordPress Installation on Ubuntu 22.04
We'll create a Bash automation script that installs WordPress and its required dependencies on Ubuntu 22.04 LTS.
The goal is to make the installation as simple as running one command on a fresh Ubuntu server. The script will install the required software, configure the database and web server, download WordPress, and prepare it for use.
1. What the script will install
We'll use the following software stack:
Component
Purpose
Ubuntu 22.04 LTS
Operating system
Apache 2
Web server
PHP
Runs WordPress
PHP extensions
Provide database connectivity and other required functionality
MySQL Server
Stores WordPress data
WordPress
Website and content management system
WP-CLI
Optional command-line management for WordPress
UFW
Firewall configuration, if enabled
How the components work together
                 Website Visitor
                        |
                     HTTPS
                        |
                        v
                 Apache Web Server
                        |
                        v
                   WordPress
                        |
                        v
                       PHP
                        |
                        v
                  MySQL Database

             Ubuntu 22.04 LTS
        (operating system underneath)

             Bash Installation Script
       (automates installation and setup)
The installation will use Ubuntu's package manager wherever possible.
2. Installation approach
We'll make the script perform these tasks automatically:
    1. Verify that the server runs Ubuntu 22.04 and that the script is run with root privileges.
    2. Update the APT package index.
    3. Install Apache, MySQL, PHP, and the required PHP extensions.
    4. Generate a random database password.
    5. Create a dedicated WordPress database and database user.
    6. Download WordPress from the official WordPress website.
    7. Install WP-CLI, which lets us configure WordPress from the terminal.
    8. Generate wp-config.php with the database credentials.
    9. Configure Apache and enable URL rewriting.
    10. Set appropriate file permissions and start the services.
    11. Complete the WordPress installation and display the website URL.
We'll use the standard Ubuntu 22.04 packages to avoid adding third-party package repositories.
Version note: Ubuntu 22.04's standard repositories provide PHP 8.1. Although WordPress retains compatibility with older PHP versions, its current recommendations call for PHP 8.3 or newer. The script below uses Ubuntu's standard PHP packages for compatibility with the requested operating system; for a new production deployment, consider a newer supported PHP release. 【turn0search0】【turn0search6】
3. Complete automated installation script
Create a file named install_wordpress.sh on your Ubuntu 22.04 server.
The following script installs and configures the complete stack and runs the WordPress installer automatically.
Important: This script is intended for a fresh server dedicated to one WordPress website. It refuses to overwrite an existing /var/www/wordpress directory. It does not automatically configure HTTPS or change firewall rules.
Step 1: Create the script
Run:
nano install_wordpress.sh
Paste the following code into the file:
---------------------------

---------------------------
Step 2: Save the script
If you are using Nano:
    1. Press Ctrl + O to save.
    2. Press Enter to confirm the filename.
    3. Press Ctrl + X to exit.
Step 3: Execute the script
Make the script executable:
chmod +x install_wordpress.sh
Run it with root privileges:
sudo ./install_wordpress.sh
The script will ask you for a few details:
============================================
 WordPress Automated Installation
 Ubuntu 22.04 LTS
============================================

Website domain (example.com), or press Enter to use server IP:
Website title:
WordPress administrator username:
Administrator email address:
Administrator password (minimum 16 characters):
For example, you could enter:
Website domain: blog.example.com
Website title: My WordPress Website
Administrator username: wpadmin
Administrator email: admin@example.com
Administrator password: [your secure password]
Use your actual domain and email address, not these example values.
The password input will be hidden while you type.
Important: This version configures HTTP, not HTTPS. If you provide a domain, make sure its DNS records point to your server before expecting the domain to work.

4. Verify the installation
After the script completes, perform these checks.
Check Apache
sudo systemctl status apache2
You should see:
Active: active (running)
Check MySQL
sudo systemctl status mysql
You should also see:
Active: active (running)
Check PHP
php -v
This displays the installed PHP version.
Check WordPress
sudo -u www-data wp core is-installed \
  --path=/var/www/wordpress
If WordPress is installed successfully, the command exits without an error.
You can also check the Apache configuration:
sudo apache2ctl configtest
Expected result:
Syntax OK
Open the website
Visit the URL displayed at the end of the installation.
For example:
http://YOUR_SERVER_IP/
To access the WordPress administration dashboard, visit:
http://YOUR_SERVER_IP/wp-admin
Log in using the administrator username and password you provided.

5. Where are the important files?
After installation, the directory structure will look approximately like this:
/var/www/wordpress/
    |
    |-- wp-admin/
    |-- wp-content/
    |-- wp-includes/
    |-- wp-config.php
    |-- index.php
    |
    +-- WordPress application files


/etc/apache2/
    |
    +-- sites-available/
    |       |
    |       +-- wordpress.conf
    |
    +-- sites-enabled/
            |
            +-- wordpress.conf


/root/
    |
    +-- wordpress-db-credentials.txt
Here is what the important files do:
File or directory
Purpose
/var/www/wordpress/
Contains the WordPress application.
wp-config.php
Contains database connection settings and other WordPress configuration.
wp-content/
Contains plugins, themes, and uploaded media.
wordpress.conf
Configures Apache to serve the WordPress website.
wordpress-db-credentials.txt
Stores the database connection credentials with restricted file permissions.
Keep wp-config.php and the database credentials secure.

6. Important production considerations
The script is a useful starting point for a single-site installation, but a few things need attention before using it for a public production website.
    • HTTPS: Configure a TLS certificate and redirect HTTP traffic to HTTPS. The script does not configure HTTPS automatically.
    • PHP version: Ubuntu 22.04's standard PHP package is older than the version currently recommended by WordPress. Plan an upgrade to a supported PHP release.
    • Firewall: The script does not modify UFW rules. If UFW is enabled, ensure the necessary web traffic is permitted without exposing MySQL publicly.
    • Backups: Configure regular backups of both the WordPress files and database.
    • File permissions: The script uses www-data ownership for simplicity. A more isolated production configuration can use a dedicated system user and PHP-FPM pool for the website.
    • Existing servers: Do not run this script on a server that already hosts websites or uses the same database names, database users, or Apache configuration paths.
For reference, Ubuntu's official documentation explains the Apache/PHP/MySQL installation process, while WordPress's documentation describes its installation requirements and configuration. 【turn0search3】【turn0search2】
7. Optional improvements
Once the basic installation works, we can extend the automation to include:
    1. Automatic HTTPS configuration using Let's Encrypt.
    2. Automatic domain and DNS preflight checks.
    3. A more secure PHP-FPM configuration.
    4. Scheduled database and file backups.
    5. Automatic WordPress, plugin, and theme maintenance.
    6. Logging and automatic recovery from installation failures.
    7. Support for installing multiple WordPress websites on the same server.
My recommendation: Start by testing this script on a fresh Ubuntu 22.04 virtual machine. Once it installs WordPress successfully and you can log in, add HTTPS and production security settings before exposing the website to the public.

