get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" | jq --raw-output .tag_name
}

get_architecture() {
  case "$(uname -m)" in
  aarch64)
    echo "arm64"
    ;;
  arm64)
    echo "arm64"
    ;;
  x86_64)
    echo "amd64"
    ;;
  amd64)
    echo "amd64"
    ;;
  *)
    echo ""
    ;;
  esac
}

ARCH=$(get_architecture)

if [ -z "$ARCH" ]; then
  echo 1>&2 "ERROR: Architecture $(uname -m) is not supported."
  exit 1
fi

NGINX_VERSION="1.23.3"
RELEASE_TAG=$(get_latest_release DataDog/nginx-datadog)
TARBALL="ngx_http_datadog_module-${ARCH}-${NGINX_VERSION}.so.tgz"

curl -Lo ${TARBALL} "https://github.com/DataDog/nginx-datadog/releases/download/${RELEASE_TAG}/${TARBALL}"
tar -xf ${TARBALL} -C /usr/lib/nginx/modules
rm ${TARBALL}
