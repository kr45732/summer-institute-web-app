# Base Sinatra App for Summer Institute

![GitHub Release](https://img.shields.io/github/release/osc/ood-example-ps.svg)
[![GitHub License](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT)

This app is meant as a base Passenger app that runs in an [OnDemand] portal
that uses the [Sinatra] web framework for OSC's [Summer Institute].

Feel free to modify it anyway you see fit.

## Deploy

The directions below require Ruby and Bundler be installed and accessible from
the command line. If using a machine that has [Software Collections] you may
want to run the following command beforehand:

```console
$ module load ruby/2.7.3
```

1. To deploy and run this app you will need to first go to your OnDemand
   sandbox directory (if it doesn't exist, then we create it):

   ```console
   $ mkdir -p ~/ondemand/dev
   $ cd ~/ondemand/dev
   ```

2. Then clone down this app and `cd` into it:

   ```console
   $ git clone git@github.com:OSC/si-19-sinatra-base.git my_app
   Cloning into 'my_app'...
   $ cd my_app
   ```

3. Setup the app before you use it:

   ```console
   $ bin/setup

   ...
   ```

4. Now you should be able to access this app from OSC OnDemand at
   https://ondemand.osc.edu/pun/dev/my_app/

   Note: You may need to replace the domain above with your center's OnDemand
   portal location if not using OSC.

[OnDemand]: http://openondemand.org/
[Sinatra]: http://sinatrarb.com/
[Summer Institute]: https://www.osc.edu/education/si
