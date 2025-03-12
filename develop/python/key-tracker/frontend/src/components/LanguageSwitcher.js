import React from 'react';
import { useTranslation } from 'react-i18next';
import { NavDropdown } from 'react-bootstrap';

const LanguageSwitcher = () => {
  const { t, i18n } = useTranslation();
  
  const changeLanguage = (lng) => {
    i18n.changeLanguage(lng);
  };
  
  return (
    <NavDropdown 
      title={t('language.select')} 
      id="language-switcher-dropdown"
    >
      <NavDropdown.Item 
        onClick={() => changeLanguage('en')}
        active={i18n.language === 'en'}
      >
        {t('language.en')}
      </NavDropdown.Item>
      <NavDropdown.Item 
        onClick={() => changeLanguage('ua')}
        active={i18n.language === 'ua'}
      >
        {t('language.ua')}
      </NavDropdown.Item>
    </NavDropdown>
  );
};

export default LanguageSwitcher;
