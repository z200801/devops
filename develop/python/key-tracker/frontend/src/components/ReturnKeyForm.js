import React, { useState, useEffect } from 'react';
import { Container, Form, Button, Alert } from 'react-bootstrap';
import { useNavigate, useLocation } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import axios from 'axios';

const API_URL = '/api';

const ReturnKeyForm = () => {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const location = useLocation();

  // Отримуємо параметр siteCode з URL
  const queryParams = new URLSearchParams(location.search);
  const preselectedSiteCode = queryParams.get('siteCode');

  const [formData, setFormData] = useState({
    site_code: '',
    returned_at: new Date().toISOString().slice(0, 16),
    memo: ''
  });
  
  const [issuedKeys, setIssuedKeys] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  
  useEffect(() => {
    fetchIssuedKeys();
  }, []);
 
  // Ефект, який оновлює formData, коли змінюється preselectedSiteCode
  useEffect(() => {
    if (preselectedSiteCode) {
      setFormData(prevData => ({
        ...prevData,
        site_code: preselectedSiteCode
      }));
    }
  }, [preselectedSiteCode]);
 
  const fetchIssuedKeys = async () => {
    try {
      // Отримати всі ключі
      const keysResponse = await axios.get(`${API_URL}/keys/`);
      
      // Отримати всі об'єкти
      const sitesResponse = await axios.get(`${API_URL}/sites/`);
      
      // Знаходимо видані ключі і додаємо інформацію про об'єкт
      const issuedKeysData = keysResponse.data
        .filter(key => key.is_issued)
        .map(key => {
          const site = sitesResponse.data.find(s => s.site_code === key.site_code);
          return {
            ...key,
            site_address: site ? site.address : t('returnKeyForm.unknownAddress')
          };
        });
      
      setIssuedKeys(issuedKeysData);
    } catch (err) {
      console.error('Error fetching issued keys:', err);
      setError(t('returnKeyForm.errorFetchingKeys'));
    }
  };
  
  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData({ ...formData, [name]: value });
  };
  
  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    
    try {
      await axios.post(`${API_URL}/keys/return/`, formData);
      navigate('/active');
    } catch (err) {
      console.error('Error returning key:', err);
      setError(t('returnKeyForm.errorReturning'));
    } finally {
      setLoading(false);
    }
  };
  
  return (
    <Container>
      <h1>{t('returnKeyForm.title')}</h1>
      
      {error && <Alert variant="danger">{error}</Alert>}
      
      {issuedKeys.length === 0 ? (
        <Alert variant="info">
          {t('returnKeyForm.noIssuedKeys')}
        </Alert>
      ) : (
        <Form onSubmit={handleSubmit}>
          <Form.Group className="mb-3">
            <Form.Label>{t('returnKeyForm.fields.site')}</Form.Label>
            <Form.Select
              name="site_code"
              value={formData.site_code}
              onChange={handleChange}
              required
            >
              <option value="">{t('keyForm.fields.selectSite')}</option>
              {issuedKeys.map((key) => (
                <option key={key.key_id} value={key.site_code}>
                  {key.site_code} - {key.site_address} ({key.description})
                </option>
              ))}
            </Form.Select>
          </Form.Group>
          
          <Form.Group className="mb-3">
            <Form.Label>{t('returnKeyForm.fields.returnedAt')}</Form.Label>
            <Form.Control
              type="datetime-local"
              name="returned_at"
              value={formData.returned_at}
              onChange={handleChange}
            />
          </Form.Group>
          
          <Form.Group className="mb-3">
            <Form.Label>{t('returnKeyForm.fields.notes')}</Form.Label>
            <Form.Control
              as="textarea"
              name="memo"
              value={formData.memo}
              onChange={handleChange}
              rows={3}
            />
          </Form.Group>
          
          <div className="d-flex gap-2">
            <Button
              variant="primary"
              type="submit"
              disabled={loading}
            >
              {loading ? t('returnKeyForm.buttons.processing') : t('returnKeyForm.buttons.return')}
            </Button>
            
            <Button
              variant="secondary"
              onClick={() => navigate('/active')}
            >
              {t('returnKeyForm.buttons.cancel')}
            </Button>
          </div>
        </Form>
      )}
    </Container>
  );
};

export default ReturnKeyForm;

