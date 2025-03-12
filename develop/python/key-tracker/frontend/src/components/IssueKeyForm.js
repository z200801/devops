import React, { useState, useEffect } from 'react';
import { Container, Form, Button, Alert, ListGroup } from 'react-bootstrap';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import axios from 'axios';

const API_URL = '/api';

const IssueKeyForm = () => {
  const { t } = useTranslation();
  const navigate = useNavigate();
  
  const [formData, setFormData] = useState({
    site_code: '',
    issued_to: '',
    issued_at: new Date().toISOString().slice(0, 16)
  });
  
  const [sites, setSites] = useState([]);
  const [availableSites, setAvailableSites] = useState([]);
  const [filteredSites, setFilteredSites] = useState([]);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  
  useEffect(() => {
    fetchSitesAndKeys();
  }, []);
  
  // Ефект для фільтрації сайтів при введенні тексту
  useEffect(() => {
    if (formData.site_code) {
      const input = formData.site_code.toString().toLowerCase();
      
      const filtered = availableSites.filter(site => {
        const siteCode = site.site_code.toString().toLowerCase();
        const siteAddress = site.address.toString().toLowerCase();
        
        const matchesSiteCode = siteCode.includes(input);
        const matchesAddress = siteAddress.includes(input);
        
        return matchesSiteCode || matchesAddress;
      });
      
      setFilteredSites(filtered);
      setShowSuggestions(filtered.length > 0);
    } else {
      setFilteredSites([]);
      setShowSuggestions(false);
    }
  }, [formData.site_code, availableSites]);
  
  const fetchSitesAndKeys = async () => {
    try {
      // Отримати всі об'єкти
      const sitesResponse = await axios.get(`${API_URL}/sites/`);
      setSites(sitesResponse.data);
      
      // Отримати всі ключі
      const keysResponse = await axios.get(`${API_URL}/keys/`);
      
      // Фільтруємо лише ті об'єкти, для яких є доступні ключі
      const availableSiteCodes = keysResponse.data
        .filter(key => !key.is_issued)
        .map(key => key.site_code);
      
      // Фільтруємо об'єкти
      const availableSitesData = sitesResponse.data
        .filter(site => availableSiteCodes.includes(site.site_code));
      
      setAvailableSites(availableSitesData);
    } catch (err) {
      console.error('Error fetching data:', err);
      setError(t('issueKeyForm.errorFetchingData'));
    }
  };
  
  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData({ ...formData, [name]: value });
  };

  const handleSiteSelect = (site) => {
    setFormData({ ...formData, site_code: site.site_code });
    setShowSuggestions(false);
  };
  
  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    
    try {
      // Перевірка, чи існує вибраний об'єкт
      const siteExists = availableSites.some(site => site.site_code === formData.site_code);
      
      if (!siteExists) {
        setError(t('issueKeyForm.errorSiteNotFound'));
        setLoading(false);
        return;
      }
      
      await axios.post(`${API_URL}/keys/issue/`, formData);
      navigate('/active');
    } catch (err) {
      console.error('Error issuing key:', err);
      setError(t('issueKeyForm.errorIssuing'));
    } finally {
      setLoading(false);
    }
  };
  
  return (
    <Container>
      <h1>{t('issueKeyForm.title')}</h1>
      
      {error && <Alert variant="danger">{error}</Alert>}
      
      {availableSites.length === 0 ? (
        <Alert variant="warning">
          {t('issueKeyForm.noAvailableKeys')}
        </Alert>
      ) : (
        <Form onSubmit={handleSubmit}>
          <Form.Group className="mb-3 position-relative">
            <Form.Label>{t('issueKeyForm.fields.site')}</Form.Label>
            <Form.Control
              type="text"
              name="site_code"
              value={formData.site_code}
              onChange={handleChange}
              required
              autoComplete="off"
              placeholder={t('issueKeyForm.fields.site')}
              onFocus={() => {
                if (!formData.site_code) {
                  setFilteredSites(availableSites);
                }
                setShowSuggestions(true);
              }}
              onBlur={() => {
                // Затримка, щоб користувач міг натиснути на пункт списку
                setTimeout(() => {
                  setShowSuggestions(false);
                }, 200);
              }}
            />            
            {showSuggestions && filteredSites.length > 0 && (
              <ListGroup 
                className="position-absolute w-100 mt-1 z-index-dropdown" 
                style={{ zIndex: 1000 }}
              >
                {filteredSites.map((site) => (
                  <ListGroup.Item 
                    key={site.site_id}
                    action
                    onClick={() => handleSiteSelect(site)}
                  >
                    {site.site_code} - {site.address}
                  </ListGroup.Item>
                ))}
              </ListGroup>
            )}
          </Form.Group>
          
          <Form.Group className="mb-3">
            <Form.Label>{t('issueKeyForm.fields.issuedTo')}</Form.Label>
            <Form.Control
              type="text"
              name="issued_to"
              value={formData.issued_to}
              onChange={handleChange}
              required
            />
          </Form.Group>
          
          <Form.Group className="mb-3">
            <Form.Label>{t('issueKeyForm.fields.issuedAt')}</Form.Label>
            <Form.Control
              type="datetime-local"
              name="issued_at"
              value={formData.issued_at}
              onChange={handleChange}
            />
          </Form.Group>
          
          <div className="d-flex gap-2">
            <Button
              variant="primary"
              type="submit"
              disabled={loading}
            >
              {loading ? t('issueKeyForm.buttons.processing') : t('issueKeyForm.buttons.issue')}
            </Button>
            
            <Button
              variant="secondary"
              onClick={() => navigate('/active')}
            >
              {t('issueKeyForm.buttons.cancel')}
            </Button>
          </div>
        </Form>
      )}
    </Container>
  );
};

export default IssueKeyForm;

