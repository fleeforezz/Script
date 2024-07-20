#!/bin/bash

# Print out the job is starting
echo 'Starting'

ansible-playbook playbooks.yml --user nhat --ask-pass --ask-become-pass -i hosts

# Print out if the job is complete
echo 'Run complete !!!'
