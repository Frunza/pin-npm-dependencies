# Pin NPM dependencies

## Motivation

When you develop your project using `npm` as a dependency manager, it is important to pin all dependencies. While you should update your dependencies regularly, this should not happen unintentionally, and all pipeline steps should produce the same result.

## Prerequisites

A Linux or MacOS machine for local development. If you are running Windows, you first need to set up the *Windows Subsystem for Linux (WSL)* environment.

You need `docker cli` and `docker-compose` on your machine for testing purposes, and/or on the machines that run your pipeline.
You can check both of these by running the following commands:
```sh
docker --version
docker-compose --version
```

## Investigation

Let's start by creating a project that has a 3rd party dependency. Put the following into your `index.js`:
```sh
const axios = require('axios');

async function fetchData() {
  try {
    const response = await axios.get('https://jsonplaceholder.typicode.com/todos/1');
    console.log(response.data);
  } catch (error) {
    console.error('Error fetching data:', error);
  }
}

fetchData();
```

Generate the `package.json` file by running:
```sh
npm init -y
```
, or create it manually.

Add the 3rd party dependency we are using to `package.json`:
```sh
  "dependencies": {
    "axios": "^1.7.0"
  }
```
If you take a closer look at the dependency, you might notice the caret symbol `^` near the dependency version. This will tell `npm` to use the latest patch and minor version of this dependency. So this declaration here is not meant to pin the dependencies, but to define them by some rules.

The exact dependency versions are found in a `package-lock.json` file. This file is generated after running `npm install`, for example.

The repository already contains a `package-lock.json` file, which currently has the following version of `axios`:
```sh
    "node_modules/axios": {
      "version": "1.7.1",
      "resolved": "https://registry.npmjs.org/axios/-/axios-1.7.1.tgz",
      "integrity": "sha512-+LV37nQcd1EpFalkXksWNBiA17NZ5m5/WspmHGmZmdx1qBOg/VNq/c4eRJiA9VQQHBOs+N0ZhhdU10h2TyNK7Q==",
      "dependencies": {
        "follow-redirects": "^1.15.6",
        "form-data": "^4.0.0",
        "proxy-from-env": "^1.1.0"
      }
    }
```
Note that the `integrity` field contains a hash. This means that modifying the `version` by hand can cause problems due to hash mismatches.

The correct way to pin the `npm` dependencies is to use such a `package-lock.json` file and add it to your repository, but also to use `npm clean-install` instead of `npm install`. `npm clean-install` will add the versions found in the `package-lock.json` file. `npm install` does not guarantee the usage of the versions found in the `package-lock.json` file.

Let's test this all out. The plan is the following:
1) Recommended way
Since the repository comes with a `package-lock.json` file, let's use `npm clean-install` first to install the node modules and put them in a tarball.
2) Not recommended way
Get rid of the `package-lock.json` file and use `npm install` to install the node modules and put them in a second tarball.
3) Compare results
In this step we want to generate hashes for the 2 tarballs and display them to see if they are the same.

## Step 1

Before we start, let's take a second look at the `package-lock.json` file:
```sh
    "node_modules/axios": {
      "version": "1.7.1",
      "resolved": "https://registry.npmjs.org/axios/-/axios-1.7.1.tgz",
      "integrity": "sha512-+LV37nQcd1EpFalkXksWNBiA17NZ5m5/WspmHGmZmdx1qBOg/VNq/c4eRJiA9VQQHBOs+N0ZhhdU10h2TyNK7Q==",
      "dependencies": {
        "follow-redirects": "^1.15.6",
        "form-data": "^4.0.0",
        "proxy-from-env": "^1.1.0"
      }
    }
```
Do note that the `axios` dependency has 3 other dependencies as well. Are the other dependencies also pinned in the `package-lock.json` file? If we investigate more parts of it, we notice:
```sh
    "node_modules/follow-redirects": {
      "version": "1.15.6",
      "resolved": "https://registry.npmjs.org/follow-redirects/-/follow-redirects-1.15.6.tgz",
```
```sh
    "node_modules/form-data": {
      "version": "4.0.0",
      "resolved": "https://registry.npmjs.org/form-data/-/form-data-4.0.0.tgz",
```
```sh
    "node_modules/proxy-from-env": {
      "version": "1.1.0",
      "resolved": "https://registry.npmjs.org/proxy-from-env/-/proxy-from-env-1.1.0.tgz",
      "integrity": "sha512-D+zkORCbA9f1tdWRK0RaCR3GPv50cMxcrz4X8k5LTSUD1Dkw47mKJEZQNunItRTkWwgtaUSo1RVFRIG9ZXiFYg=="
    }
```
so the other dependencies are also pinned in the `package-lock.json` file.

Let's write a script to make a tarball out of `node_modules`:
```sh
npm clean-install
tar --sort=name --mtime='UTC 2023-01-01' -cf output/output1.tar node_modules
```
Since we will later use the hash of the tarball for comparison, it is important to keep the structure consistent by sorting the elements and adding the same timestamp as metadata to all files. The tarball will be stored in an `output` directory.

We want to use docker containers to do these tests since we might have some newer software versions locally. Let's build the `dockerfile`:
```sh
FROM node:21.6.2-alpine3.19

RUN apk update && apk add tar perl

ADD . /app
WORKDIR /app

CMD ["sh"]
```

Let's write the docker-compose file for the first step. We want to mount the `output` directory as a volume so that we also have access to it locally and run the script we just wrote:
```sh
services:
  generate1:
    image: nodeimage
    network_mode: host
    working_dir: /app
    volumes:
      - ./output:/app/output
    entrypoint: ["sh", "-c"]
    command: ["sh scripts/generate1.sh"]
```

## Step 2

Let's write a similar script to make a tarball out of `node_modules`. The difference is that we will use the `npm install` command instead of `npm clean-install` and delete the `package-lock.json` file:
```sh
rm -f package-lock.json
npm install
tar --sort=name --mtime='UTC 2023-01-01' -cf output/output2.tar node_modules
```

We can reuse the `dockerfile`. For this step, we can just write a second service in the docker-compose file to run the script:
```sh
  generate2:
    image: nodeimage
    network_mode: host
    working_dir: /app
    volumes:
      - ./output:/app/output
    entrypoint: ["sh", "-c"]
    command: ["sh scripts/generate2.sh"]
```

## Step 3

First of all, let's write the script for this step. We want to generate hash files from the 2 outputs and just print them:
```sh
SHA1=$(sha256sum output/output1.tar | awk '{print $1}')
SHA2=$(sha256sum output/output2.tar | awk '{print $1}')

echo "Printing the hashes of the generated node_modules tarballs, with and without package-lock.json:"
echo $SHA1
echo $SHA2
```

We can reuse the `dockerfile`. For this step, we can just write a third service in the docker-compose file to run the script:
```sh
  compare:
    image: nodeimage
    network_mode: host
    working_dir: /app
    volumes:
      - ./output:/app/output
    entrypoint: ["sh", "-c"]
    command: ["sh scripts/compare.sh"]
```

Let's add all these steps and add some cleanup as well in `run.sh`:
```sh
# Cleanup
rm -rf output

# Build the Docker image
docker build -t nodeimage .

# Generate the node_modules tarball generated by using npm clean-install
docker-compose run --rm generate1

# Generate the node_modules tarball generated by using npm install withput package-lock.json
docker-compose run --rm generate2

# Compare the two tarballs. This will print their respective SHA1 checksums
docker-compose run --rm compare
```

Calling
```sh
sh run.sh
```
will generate 2 different node_modules from steps 1 and 2 and print the hash from their respective tarball.
If the hashes are different, then the content of the tarballs is different as well. To find out the exact differences, you can unpack the tarballs and investigate each file, or use some other tools; a free one that can be accessed over the internet is [diffchecker](https://www.diffchecker.com/text-compare/), but you might have better ones that do not require you to upload your files on the internet.

You might wonder whether the 2 hashes are different just because of some factors that were not considered. That is a fair question. You can make sure that this is not the case just by running the `run.sh` script a second time. The expectation is to obtain the same hashes as before.

## Takeaways

When working with `npm`:
- add `package-lock.json` to your repository
- use `npm clean-install` when building the product in the pipeline
- to update dependencies, either update them in the `package.json` file or use `npm update` to update all dependencies and checkout an updated `package-lock.json` file
