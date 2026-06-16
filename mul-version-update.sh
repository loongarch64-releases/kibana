#!/bin/bash

# 定义主版本号和次版本号的循环范围
# 例如：从 v3.6.x 到 v4.7.x
#START_MAJOR=3
#END_MAJOR=4
START_MAJOR=3
END_MAJOR=3

START_MINOR=5
END_MINOR=5

# 定义补丁版本号的循环范围
START_PATCH=10
END_PATCH=24

# 外层循环：主版本号
for MAJOR in $(seq $START_MAJOR $END_MAJOR); do
    
    # 内层循环：次版本号
    for MINOR in $(seq $START_MINOR $END_MINOR); do
        
        # 最内层循环：补丁版本号
        for PATCH in $(seq $START_PATCH $END_PATCH); do
            VERSION="v${MAJOR}.${MINOR}.${PATCH}"
            
            echo "========================================"
            echo "🚀 开始构建版本: $VERSION"
            echo "========================================"
            
            # 2. 执行构建脚本
            ./scripts/release.sh  ${VERSION} 
            echo "版本 $VERSION 处理完成。" 
            echo ""
        done
    done
done

echo "🎉 所有版本构建完成！"

