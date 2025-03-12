import React, { useState, useEffect } from 'react';
import { Container, Form, Button, Alert } from 'react-bootstrap';
import { useParams, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import axios from 'axios';

const API_URL = '/api';

const SiteForm = () => {
  const { t } = useTranslation();
  const { siteCode } = useParams();
  const navigate = useNavigate();
  const isEditMode = !!siteCode;
  
  const [formData, setFormData] = useState({
    site_code: '',
    address: '',
    memo: ''
  });
  
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  
  useEffect(() => {
    if (isEditMode) {
      fetchSite();
    }
  }, [isEditMode, siteCode]);
  
  const fetchSite = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API_URL}/sites/${siteCode}`);
      setFormData(response.data);
      setError(null);
    } catch (err) {
      console.error('Error fetching site:', err);
      setError('Помилка при завантаженні даних об\'єкту. Спробуйте пізніше.');
    } finally {
      setLoading(false);
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
      if (isEditMode) {
        await axios.put(`${API_URL}/sites/${siteCode}`, formData);
      } else {
        await axios.post(`${API_URL}/sites/`, formData);
      }
      navigate('/sites');
    } catch (err) {
      console.error('Error saving site:', err);
      setError('Помилка при збереженні об\'єкту.');
    } finally {
      setLoading(false);
    }
  };
  
  return (
    <Container>
      <h1>{isEditMode ? t('siteForm.editTitle') : t('siteForm.addTitle')}</h1>
      
      {error && <Alert variant="danger">{error}</Alert>}
      
      <Form onSubmit={handleSubmit}>
        <Form.Group className="mb-3">
          <Form.Label>{t('siteForm.fields.code')}</Form.Label>
          <Form.Control
            type="text"
            name="site_code"
            value={formData.site_code}
            onChange={handleChange}
            disabled={isEditMode}
            required
          />
        </Form.Group>
        
        <Form.Group className="mb-3">
          <Form.Label>{t('siteForm.fields.address')}</Form.Label>
          <Form.Control
            type="text"
            name="address"
            value={formData.address}
            onChange={handleChange}
            required
          />
        </Form.Group>
        
        <Form.Group className="mb-3">
          <Form.Label>{t('siteForm.fields.notes')}</Form.Label>
          <Form.Control
            as="textarea"
            name="memo"
            value={formData.memo || ''}
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
            {loading ? t('siteForm.buttons.saving') : t('siteForm.buttons.save')}
          </Button>
          
          <Button
            variant="secondary"
            onClick={() => navigate('/sites')}
          >
            {t('siteForm.buttons.cancel')}
          </Button>
        </div>
      </Form>
    </Container>
  );
};

export default SiteForm;

