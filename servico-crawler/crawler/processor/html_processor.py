from bs4 import BeautifulSoup
import re
import logging
from typing import List, Dict, Optional

logger = logging.getLogger(__name__)


class HTMLProcessor:
    CONTENT_TAGS = {
        'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
        'p',
        'li',
        'td', 'th', 
        'span', 'strong', 'em', 'b', 'i',
        'article', 'section', 'main',
        'blockquote',
        'pre', 'code',
        'figcaption'
    }
    
    REMOVE_TAGS = {
        'script', 'style', 'noscript', 'meta', 'link',
        'nav', 'footer', 'header', 'aside',
        'svg', 'canvas', 'iframe'
    }
    
    TAG_PREFIXES = {
        'h1': '\n## ',
        'h2': '\n### ',
        'h3': '\n#### ',
        'h4': '\n##### ',
        'h5': '\n###### ',
        'h6': '\n####### ',
        'p': '\n',
        'li': '\n',
        'blockquote': '\n> ',
        'pre': '\n```\n',
        'code': '`'
    }
    
    TAG_SUFFIXES = {
        'pre': '\n```\n'
    }
    
    def __init__(self, 
                 remove_nav_footer: bool = False,
                 min_word_count: int = 10,
                 max_consecutive_newlines: int = 2):
        
        self.remove_nav_footer = remove_nav_footer
        self.min_word_count = min_word_count
        self.max_consecutive_newlines = max_consecutive_newlines
        
        if remove_nav_footer:
            self.REMOVE_TAGS = self.REMOVE_TAGS | {'nav', 'footer', 'header', 'aside'}
    
    def process_html(self, html_content: str) -> str:
        try:
            soup = BeautifulSoup(html_content, 'lxml')
            
            self._remove_unwanted_tags(soup)
            
            text = self._extract_formatted_text(soup)
            
            text = self._clean_whitespace(text)
            
            return text.strip()
        
        except Exception as e:
            logger.error(f"Erro ao processar HTML: {str(e)}")
            return ""
    
    def process_html_structured(self, html_content: str) -> Dict[str, any]:
        try:
            soup = BeautifulSoup(html_content, 'lxml')
            self._remove_unwanted_tags(soup)
            
            return {
                'titles': self._extract_titles(soup),
                'paragraphs': self._extract_paragraphs(soup),
                'lists': self._extract_lists(soup),
                'tables': self._extract_tables(soup),
                'main_text': self.process_html(html_content),
                'text_only': self._extract_text_only(soup)
            }
        
        except Exception as e:
            logger.error(f"Erro ao processar HTML estruturado: {str(e)}")
            return {
                'titles': [],
                'paragraphs': [],
                'lists': [],
                'tables': [],
                'main_text': '',
                'text_only': ''
            }
    
    def _remove_unwanted_tags(self, soup: BeautifulSoup):
        for tag in soup.find_all(self.REMOVE_TAGS):
            tag.decompose()
    
    def _extract_formatted_text(self, soup: BeautifulSoup) -> str:
        result = []
        
        for element in soup.find_all(['h1', 'h2', 'h3', 'h4', 'h5', 'h6', 
                                     'p', 'li', 'blockquote', 'pre', 'code']):
            tag_name = element.name
            text = self._get_element_text(element)
            
            if not text or len(text.split()) < self.min_word_count:
                continue
            
            prefix = self.TAG_PREFIXES.get(tag_name, '\n')
            suffix = self.TAG_SUFFIXES.get(tag_name, '')
            
            result.append(f"{prefix}{text}{suffix}")
        
        return ''.join(result)
    
    def _extract_titles(self, soup: BeautifulSoup) -> List[str]:
        titles = []
        for tag in soup.find_all(['h1', 'h2', 'h3', 'h4', 'h5', 'h6']):
            text = self._get_element_text(tag)
            if text:
                titles.append(text)
        return titles
    
    def _extract_paragraphs(self, soup: BeautifulSoup) -> List[str]:
        paragraphs = []
        for p in soup.find_all('p'):
            text = self._get_element_text(p)
            if text and len(text.split()) >= self.min_word_count:
                paragraphs.append(text)
        return paragraphs
    
    def _extract_lists(self, soup: BeautifulSoup) -> List[Dict[str, any]]:
        lists = []
        
        for list_tag in soup.find_all(['ul', 'ol']):
            list_type = 'ordered' if list_tag.name == 'ol' else 'unordered'
            items = []
            
            for li in list_tag.find_all('li', recursive=False):
                text = self._get_element_text(li)
                if text:
                    items.append(text)
            
            if items:
                lists.append({
                    'type': list_type,
                    'items': items
                })
        
        return lists
    
    def _extract_tables(self, soup: BeautifulSoup) -> List[Dict[str, any]]:
        tables = []
        
        for table in soup.find_all('table'):
            table_data = {
                'headers': [],
                'rows': []
            }
            
            for th in table.find_all('th'):
                text = self._get_element_text(th)
                if text:
                    table_data['headers'].append(text)
            
            for tr in table.find_all('tr'):
                row = []
                for td in tr.find_all('td'):
                    text = self._get_element_text(td)
                    row.append(text)
                
                if row:
                    table_data['rows'].append(row)
            
            if table_data['rows'] or table_data['headers']:
                tables.append(table_data)
        
        return tables
    
    def _extract_text_only(self, soup: BeautifulSoup) -> str:
        text = soup.get_text(separator=' ', strip=True)
        text = re.sub(r'\s+', ' ', text)
        return text
    
    def _get_element_text(self, element) -> str:
        text = element.get_text(separator=' ', strip=True)
        text = re.sub(r'\s+', ' ', text)
        text = re.sub(r'\x00-\x08\x0B\x0C\x0E-\x1F\x7F', '', text)
        return text.strip()
    
    def _clean_whitespace(self, text: str) -> str:
        text = re.sub(r'\n{' + str(self.max_consecutive_newlines + 1) + r',}', 
                      '\n' * self.max_consecutive_newlines, text)
        
        lines = [line.strip() for line in text.split('\n')]
        
        cleaned_lines = []
        prev_empty = False
        
        for line in lines:
            is_empty = not line
            
            if is_empty and prev_empty:
                continue
            
            cleaned_lines.append(line)
            prev_empty = is_empty
        
        return '\n'.join(cleaned_lines)
    
    @staticmethod
    def extract_summary(html_content: str, max_length: int = 500) -> str:
        """
        Extrai um sumário do conteúdo HTML
        Útil para preview/descrição de página
        """
        processor = HTMLProcessor()
        text = processor.process_html(html_content)
        
        paragraphs = [p for p in text.split('\n') if p.strip() and not p.startswith('#')]
        
        summary = ''
        for para in paragraphs:
            if len(summary) + len(para) < max_length:
                summary += para + ' '
            else:
                break
        
        return summary.strip()[:max_length] + ('...' if len(summary) > max_length else '')