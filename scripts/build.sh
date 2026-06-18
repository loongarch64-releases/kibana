#!/bin/bash
set -euo pipefail

UPSTREAM_OWNER=elastic
UPSTREAM_REPO=kibana
VERSION="${1}"
echo "   🏢 Org:   ${UPSTREAM_OWNER}"
echo "   📦 Proj:  ${UPSTREAM_REPO}"
echo "   🏷️  Ver:   ${VERSION}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DISTS="${ROOT_DIR}/dists"
SRCS="${ROOT_DIR}/srcs"


# ==========================================
# 👇 用户自定义构建逻辑 (示例)
# ==========================================

echo "🔧 Compiling ${UPSTREAM_OWNER}/${UPSTREAM_REPO} ${VERSION}..."

# 1. 准备阶段：安装依赖、下载代码、应用补丁等
prepare()
{
    echo "📦 [Prepare] Setting up build environment..."
    
    # TODO: 在此处添加准备命令
    # 例如：apt-get update && apt-get install -y build-essential
    # 例如：git clone -b ${VERSION} --depth=1 https://github.com/openresty/openresty ${SRCS}/${VERSION}
    # 例如：patch -p1 < patches/loongarch-fix.patch
    
    if [ ! -d "${SRCS}/${VERSION}" ]; then
    	git clone -b v${VERSION} --depth=1 https://github.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO} ${SRCS}/${VERSION}
    fi

    
    echo "✅ [Prepare] Environment ready."
}

# 2. 编译阶段：核心构建命令
build()
{
    echo "🔨 [Build] Compiling source code..."
    
    # TODO: 在此处添加编译命令
    # 例如：make -j$(nproc) ARCH=loongarch64
    # 例如：cmake -DCMAKE_BUILD_TYPE=Release .. && make
    
    #进入源码读取依赖的node版本
    pushd ${SRCS}/${VERSION}
    NODE_VERSION=$(cat .node-version)
    echo "***************** Node version is ${NODE_VERSION}"
    if [ -z "$NODE_VERSION" ]; then
       echo "Error: .node-version is empty or missing"
       exit 1
    fi
    popd
    
    pushd ${SRCS}
    #下载上游kibana　tar包
    wget  https://artifacts.elastic.co/downloads/${UPSTREAM_REPO}/${UPSTREAM_REPO}-${VERSION}-linux-x86_64.tar.gz
    tar -xf ${UPSTREAM_REPO}-${VERSION}-linux-x86_64.tar.gz
    KIBANA_DIR=${UPSTREAM_REPO}-${VERSION} #读取tar包解压后的目录名称

    #下载对应的node二进制tar包，有一些版本上游不存在
    wget https://unofficial-builds.nodejs.org/download/release/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-loong64.tar.gz
    NODE_DIR=node-v${NODE_VERSION}-linux-loong64 #读取tar包解压后的目录名称
    echo "******************** NODE_DIR = ${NODE_DIR}"
    tar -xf node-v${NODE_VERSION}-linux-loong64.tar.gz
    mv -v ./${NODE_DIR} node  #重命名为node

    #替换X86 kibana 中的node目录
    rm -rf ${KIBANA_DIR}/node
    mv node ${KIBANA_DIR}/
    #高版本中x86 node二进制的路径与ＬＡ的不一致，这里替换为ＬＡ的路径,kibana低版本路径是"${DIR}/node/bin/node",所以这里不用确认高低版本，直接默认替换即可
    sed -i 's|NODE="${DIR}/node/glibc-217/bin/node"|NODE="${DIR}/node/bin/node"|g'  ${KIBANA_DIR}/bin/kibana
    sed -i 's|NODE="${DIR}/node/default/bin/node"|NODE="${DIR}/node/bin/node"|g' ${KIBANA_DIR}/bin/kibana 

    #高版本中已经不包含re2.node二进制，故这里先判断是否存在re2.node
    RE2_NODE=$(find "${KIBANA_DIR}" -name "re2.node")    
    if [ -z "${RE2_NODE}" ]; then
	echo "未找到 re2.node，跳过替换。"
    else
	wget http://cloud.loongnix.cn/releases/loongarch64/node-re2/1.24.0/re2.node
	rm -rf ${RE2_NODE}
	cp ./re2.node ${RE2_NODE}
    fi
    
    #生成loongarch的kibana tar包
    mv ${KIBANA_DIR} ${UPSTREAM_REPO}-${VERSION}-linux-loongarch64
    tar -zcf ${UPSTREAM_REPO}-${VERSION}-linux-loongarch64.tar.gz ${UPSTREAM_REPO}-${VERSION}-linux-loongarch64
    popd


    echo "✅ [Build] Compilation finished."
}

# 3. 后处理阶段：整理产物、清理临时文件、验证版本
post_build()
{
    echo "📦 [Post-Build] Organizing artifacts..."
    
    # TODO: 在此处添加整理命令
    # 例如：mkdir -p dists && cp binary dist/${VERSION}
    # 例如：strip dist/binary
    cp -rf ${SRCS}/${UPSTREAM_REPO}-${VERSION}-linux-loongarch64.tar.gz ${DISTS}/${VERSION}/
    echo "✅ [Post-Build] Artifacts ready in ./dists/${VERSION}."
}

# 主入口
main()
{
    #在下面的下载地址中版本前面不带v,所以这里添加判断，如果传入的版本前面带有v则将其去掉
    #https://artifacts.elastic.co/downloads/${UPSTREAM_REPO}/${UPSTREAM_REPO}-${VERSION}-linux-x86_64.tar.gz
    if [[ "${VERSION}" == v* ]]; then
        VERSION="${VERSION#v}"
    fi
    #将创建目录放到这里是为了保证无论命令行输入的是./script/build.sh v9.2.0或者./script/build.sh 9.2.0　创建的目录都是一致的(如9.2.0)
    mkdir -p "${DISTS}/${VERSION}" "${SRCS}"

    prepare
    build
    post_build
}

main

# ==========================================
# 👆 自定义逻辑结束
# ==========================================

cat > "${DISTS}/${VERSION}/release.txt" <<EOF
Project: ${UPSTREAM_REPO}
Organization: ${UPSTREAM_OWNER}
Version: ${VERSION}
Build Time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "✅ Compilation finished."
ls -lh "${DISTS}/${VERSION}"
