# special target: https://github.com/docker/metadata-action#bake-definition
target "meta-helper" {}

group "default" {
    targets = ["image"]
}

target "image" {
    inherits = ["meta-helper"]
    output = ["type=image"]
}

target "image-cross-legacy" {
    inherits = ["image"]
    platforms = [
        "linux/amd64",
        "linux/arm64"
    ]
}

target "image-cross-installable" {
    inherits = ["image"]
    dockerfile = "DockerfileInstallable"
    platforms = [
        "linux/amd64",
        "linux/arm64"
    ]
}