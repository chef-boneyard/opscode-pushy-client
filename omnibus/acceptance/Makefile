
chef-server:
	kitchen converge chef-server-ubuntu-1604

windows-client:
	kitchen converge push-jobs-client-windows-2012r2

ubuntu-client:
	kitchen converge push-jobs-client-ubuntu-1604

clean:
	find .chef/$* ! -name 'knife.rb' -type f -exec rm -f {} +
	kitchen destroy
