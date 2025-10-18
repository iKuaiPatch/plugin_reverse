import os
import re

def is_elf_file(file_path):
    """
    检查文件是否为ELF文件（检查文件头是否为7F 45 4C 46）
    
    Args:
        file_path: 文件路径
        
    Returns:
        如果是ELF文件返回True，否则返回False
    """
    try:
        with open(file_path, 'rb') as f:
            header = f.read(4)
            # ELF文件的魔数：0x7F 0x45 0x4C 0x46
            return header == b'\x7f\x45\x4c\x46'
    except Exception:
        return False

def find_files_with_string(root_dir, search_string):
    """
    遍历指定目录下的所有文件和文件夹，寻找ELF文件且包含指定字符串的文件
    
    Args:
        root_dir: 要搜索的根目录
        search_string: 要搜索的字符串
        
    Returns:
        同时是ELF文件且包含指定字符串的文件列表
    """
    matching_files = []
    
    for root, dirs, files in os.walk(root_dir):
        for file in files:
            file_path = os.path.join(root, file)
            if is_elf_file(file_path):
                try:
                    with open(file_path, 'rb') as f:
                        content = f.read()
                        if search_string.encode('utf-8') in content:
                            matching_files.append(file_path)
                            print(f"✓ ELF文件包含目标字符串: {file_path}")
                except Exception as e:
                    print(f"无法读取ELF文件 {file_path}: {e}")
                    continue
    
    return matching_files

def find_sh2c(path: str) -> list:
    return find_files_with_string(path, "/tmp/scr")

def main():
    # 设置要搜索的目录和字符串
    search_directory = './'
    
    search_string = "/tmp/scr"
    
    print(f"开始在目录 '{search_directory}' 中搜索ELF文件且包含 '{search_string}' 的文件...")
    print("=" * 60)
    
    # 执行搜索
    result_files = find_files_with_string(search_directory, search_string)
    
    print("=" * 60)
    print(f"搜索完成！共找到 {len(result_files)} 个同时满足条件的文件（ELF格式且包含目标字符串）:")
    
    # 打印结果列表
    for i, file_path in enumerate(result_files, 1):
        print(f"{i}. {file_path}")
    return result_files

if __name__ == "__main__":
    main()