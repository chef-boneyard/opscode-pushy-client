# Push Client Omnibus Local Acceptance Environment

This environment should be use for acceptance testing on Push Jobs Client
omnibus packages. It's primary purpose is to give you a quick testing
environment that may or may not fit all your needs.

## Getting Started

First, build your Chef Server.

    make chef-server

Then, build the client of your choice, either Ubuntu OR Windows.

    make ubuntu-client
    make windows-client

## Using the Windows VM

The default Windows VM listed in the `.kitchen.yml` file is a private image
available to Chef employees. This is done because of licensing. If you want to
use your own Windows image, you can override it using a `.kitchen.local.yml`
or by temporarily over-writing the value in `.kitchen.yml`.

## Cleanup

To destroy the VM and cleanup all the associated artifacts, run the following:

    make clean
