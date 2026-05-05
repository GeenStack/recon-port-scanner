#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Скрипт генерации итогового отчета по сканированию портов
Объединяет результаты всех сканов в единый JSON отчет
"""

import json
import os
import sys
import glob
import xmltodict
from datetime import datetime
import re

def parse_nmap_xml(xml_file):
    """Парсинг XML файла nmap"""
    try:
        with open(xml_file, 'r') as f:
            data = xmltodict.parse(f.read())
        return data
    except Exception as e:
        print(f"Error parsing {xml_file}: {e}")
        return None

def extract_ports_from_xml(xml_data):
    """Извлечение информации о портах из XML"""
    ports = []
    
    try:
        if 'nmaprun' not in xml_data:
            return ports
            
        host = xml_data['nmaprun'].get('host', {})
        if not host:
            return ports
            
        ports_data = host.get('ports', {}).get('port', [])
        
        # Если один порт, преобразуем в список
        if isinstance(ports_data, dict):
            ports_data = [ports_data]
        
        for port in ports_data:
            port_info = {
                'port': port.get('@portid', ''),
                'protocol': port.get('@protocol', 'tcp'),
                'state': port.get('state', {}).get('@state', 'unknown'),
                'service': {},
                'scripts': []
            }
            
            # Информация о сервисе
            service = port.get('service', {})
            if service:
                port_info['service'] = {
                    'name': service.get('@name', ''),
                    'product': service.get('@product', ''),
                    'version': service.get('@version', ''),
                    'extrainfo': service.get('@extrainfo', ''),
                    'ostype': service.get('@ostype', ''),
                    'method': service.get('@method', ''),
                    'conf': service.get('@conf', '')
                }
            
            # Результаты скриптов
            scripts = port.get('script', [])
            if isinstance(scripts, dict):
                scripts = [scripts]
            
            for script in scripts:
                script_info = {
                    'id': script.get('@id', ''),
                    'output': script.get('@output', '')
                }
                port_info['scripts'].append(script_info)
            
            ports.append(port_info)
    
    except Exception as e:
        print(f"Error extracting ports: {e}")
    
    return ports

def find_log_files(log_dir, ip):
    """Поиск всех файлов логов для конкретного IP"""
    safe_ip = ip.replace('.', '_')
    pattern = os.path.join(log_dir, f"{safe_ip}_*")
    files = glob.glob(pattern)
    
    log_files = {
        'fast_scan': [],
        'detailed_scan': [],
        'vuln_scan': []
    }
    
    for f in files:
        basename = os.path.basename(f)
        if '_fast_' in basename:
            log_files['fast_scan'].append(basename)
        elif '_detailed_' in basename:
            log_files['detailed_scan'].append(basename)
        elif '_vuln_' in basename:
            log_files['vuln_scan'].append(basename)
    
    return log_files

def generate_report(log_dir, output_file, input_data=None):
    """Генерация итогового отчета"""
    
    report = {
        'scan_date': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
        'scan_info': {
            'tool': 'recon-port-scanner',
            'version': '1.0.0'
        },
        'hosts': []
    }
    
    # Если есть входные данные из предыдущего этапа
    if input_data:
        report['input_source'] = input_data.get('domain', 'unknown')
        ips_to_scan = [ip_info['ip'] for ip_info in input_data.get('ips', [])]
    else:
        # Иначе ищем все уникальные IP в логах
        ips_to_scan = set()
        for filename in os.listdir(log_dir):
            match = re.match(r'(\d+_\d+_\d+_\d+)_', filename)
            if match:
                ip = match.group(1).replace('_', '.')
                ips_to_scan.add(ip)
        ips_to_scan = list(ips_to_scan)
    
    print(f"Processing {len(ips_to_scan)} hosts...")
    
    for ip in ips_to_scan:
        print(f"Processing {ip}...")
        
        host_info = {
            'ip': ip,
            'log_files': find_log_files(log_dir, ip),
            'ports': [],
            'scan_summary': {
                'total_ports_found': 0,
                'open_ports': 0,
                'filtered_ports': 0,
                'closed_ports': 0
            }
        }
        
        # Поиск последнего детального скана
        safe_ip = ip.replace('.', '_')
        detailed_xmls = sorted(glob.glob(os.path.join(log_dir, f"{safe_ip}_detailed_*_nmap.xml")))
        vuln_xmls = sorted(glob.glob(os.path.join(log_dir, f"{safe_ip}_vuln_*_nmap.xml")))
        
        # Парсинг детального скана
        if detailed_xmls:
            xml_data = parse_nmap_xml(detailed_xmls[-1])
            if xml_data:
                ports = extract_ports_from_xml(xml_data)
                host_info['ports'].extend(ports)
        
        # Парсинг vuln скана (добавляем скрипты к существующим портам)
        if vuln_xmls:
            xml_data = parse_nmap_xml(vuln_xmls[-1])
            if xml_data:
                vuln_ports = extract_ports_from_xml(xml_data)
                
                # Объединяем результаты
                for vport in vuln_ports:
                    found = False
                    for port in host_info['ports']:
                        if port['port'] == vport['port']:
                            # Добавляем скрипты из vuln скана
                            port['scripts'].extend(vport['scripts'])
                            found = True
                            break
                    
                    if not found:
                        host_info['ports'].append(vport)
        
        # Подсчет статистики
        for port in host_info['ports']:
            state = port.get('state', 'unknown')
            if state == 'open':
                host_info['scan_summary']['open_ports'] += 1
            elif state == 'filtered':
                host_info['scan_summary']['filtered_ports'] += 1
            elif state == 'closed':
                host_info['scan_summary']['closed_ports'] += 1
        
        host_info['scan_summary']['total_ports_found'] = len(host_info['ports'])
        
        report['hosts'].append(host_info)
    
    # Сохранение отчета
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    
    print(f"\nReport generated: {output_file}")
    print(f"Total hosts scanned: {len(report['hosts'])}")
    
    return report

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python3 04_generate_report.py <log_dir> <output_file> [input_json]")
        print("Example: python3 04_generate_report.py /app/logs /app/output/report.json /app/input/subdomains.json")
        sys.exit(1)
    
    log_dir = sys.argv[1]
    output_file = sys.argv[2]
    input_json = sys.argv[3] if len(sys.argv) > 3 else None
    
    input_data = None
    if input_json and os.path.exists(input_json):
        with open(input_json, 'r') as f:
            input_data = json.load(f)
    
    generate_report(log_dir, output_file, input_data)
