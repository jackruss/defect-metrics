#!/bin/bash

#export INETCREDENTIALS=xxxxxxxxxxxxxxx
#export PT_TOKEN=xxxxxxxxxxxxxxx
export RUBY=/home/attuser/.rvm/rubies/ruby-2.0.0-p481/bin/ruby
export MYDIR=/home/attuser/git/defect-metrics

cd $MYDIR
$RUBY $MYDIR/metrics.rb

lftp sftp://$INETCREDENTIALS@onyx  -e "cd /var/www/wordpress/wp-content/uploads/2013/02; lcd $MYDIR; put qa.html; put style.css; lcd output; put defect_status.html; put all_defect_info.html; put weekly_defect_update.html; put defect_backlog.png; put defect_backlog.html; put defect_arrivals.png; put defect_arrivals.html; bye"
