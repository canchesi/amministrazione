install:
	@echo "Installing..."
	@make create_necessary			# Create necessary files
	@make compile					# Compile backctl and backd
	@make create_daemon				# Create daemon
	@echo "Installation complete."

create_necessary:
	@groupadd back -r > /dev/null 2>&1 		# Create back group
	@mkdir -p /etc/back/keys/old			# Create /etc/ directories
	@chown -R root:back /etc/back			# Set permissions
	@chmod 2755 -R /etc/back				# Set permissions
	@echo "{}" > /etc/back/user.json		# Create user.json
	@mv ./back.conf /etc/back/back.conf		# Move back.conf
	@chown root:back /etc/back/back.conf	# Set permissions
	@mkdir -p /var/back-a-la				# Create /var/ directories
	@chown -R root:back /var/back-a-la		# Set permissions
	@chmod 2755 -R /var/back-a-la			# Set permissions
	@echo "Necessary files created."

compile:
	@echo "Compiling..."
	@make install_dependencies				# Install dependencies
	@make compile_client					# Compile backctl
	@make compile_daemon					# Compile backd
	@echo "Compilation complete."


install_dependencies:
	@echo "Installing dependencies..."
	@apt update && apt install -y libpar-packer-perl cpanminus cron perl  > /dev/null 2>&1		# Install dependencies
	@cpanm Switch JSON Text::ASCIITable File::Slurp Thread File::Finder > /dev/null 2>&1		# Install dependencies
	@echo "Dependencies installed."

compile_client:
	@pp -o /usr/local/bin/backctl ./bin/back.pl			# Compile backctl
	@chmod +x /usr/local/bin/backctl					# Set permissions
	@chown root:back /usr/local/bin/backctl				# Set permissions

compile_daemon:
	@pp -M Switch -M JSON -M Text::ASCIITable -M File::Slurp -M Thread -M File::Finder -o /usr/local/bin/backd backd.pl		# Compile backd
	@chmod +x /usr/local/bin/backd																							# Set permissions
	@chown root:back /usr/local/bin/backd																					# Set permissions
	@make reload																											# Reload daemon 

create_daemon:
	@cp ./back.service /etc/systemd/system/back.service	    # Copy back.service
	@make reload											# Reload daemon

uninstall:
	@rm -rf /usr/local/bin/backctl				# Remove backctl
	@rm -rf /usr/local/bin/backd				# Remove backd
	@rm -rf /etc/systemd/system/back.service	# Remove back.service
	@systemctl daemon-reload					# Reload daemon
	@systemctl disable --now back.service		# Disable and stop daemon
	@echo "Uninstall complete."					

reload:
	@systemctl daemon-reload					# Reload daemon
	@systemctl restart back.service				# Restart daemon
	@echo "Reload complete."