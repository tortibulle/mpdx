[![Build Status](https://travis-ci.org/CruGlobal/mpdx.png?branch=master)](https://travis-ci.org/CruGlobal/mpdx)

MPDX
====

MPDX is an online tool designed to help you maintain and improve your relationships with your ministry partners. 

## Local setup

### Requirements

* PostgreSQL
* Memcached

### Setup

Copy the example configuration files to active configuration files:

```bash
$ cd config
$ cp database.example.yml database.yml
$ cp config.example.yml config.yml
$ cp cloudinary.example.yml cloudinary.yml
```

### Install Gems

```bash
$ bundle install
```

### Create databases

```bash
$ bundle exec rake db:create:all
```

### Run migrations

```bash
$ bundle exec rake db:migrate
```

### Start Server

```bash
$ bundle exec rails s
```

## Bugs Reports & Contributing

* Bug Reports: https://github.com/CruGlobal/mpdx/issues
* Want to Contribute? Read the Guide: https://github.com/CruGlobal/mpdx/blob/master/CONTRIBUTING.md

## LICENSE:

MIT License

Copyright (c) 2012

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
