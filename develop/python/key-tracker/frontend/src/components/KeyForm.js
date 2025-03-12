import React, { useState, useEffect } from 'react';
import { Container, Form, Button, Alert } from 'react-bootstrap';
import { useParams, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import axios from 'axios';

const API_URL = '/api';

const KeyForm = () => {
  const { t } = useTranslation();
  const { keyId } = useParams();
  const navigate = useNavigate();
  const isEditMode = !!keyId;
  
  const [formData, setFormData] = useState({
    site_code: '',
    description: '',
    key_count: 1,
    set_count: 1,
    memo: ''
  });
  
  const [sites, setSites] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  
  useEffect(() => {
    fetchSites();
    
    if (isEditMode) {
      fetchKey();
    }
  }, [isEditMode, keyId]);
  
  const fetchSites = async () => {
    try {
      const response = await axios.get(`${API_URL}/sites/`);
      setSites(response.data);
    } catch (err) {
      console.error('Error fetching sites:', err);
      setError('Помилка при завантаженні списку об\'єктів.');
    }
  };
  
  const fetchKey = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API_URL}/keys/${keyId}`);
      setFormData(response.data);
      setError(null);
    } catch (err) {
      console.error('Error fetching key:', err);
      setError('Помилка при завантаженні даних ключа. Спробуйте пізніше.');
    } finally {
      setLoading(false);
    }
  };
  
  const handleChange = (e) => {
    const { name, value, type } = e.target;
    setFormData({ 
      ...formData, 
      [name]: type === 'number' ? parseInt(value, 10) : value 
    });
  };
  
  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    
    try {
      if (isEditMode) {
        await axios.put(`${API_URL}/keys/${keyId}`, formData);
      } else {
        await axios.post(`${API_URL}/keys/`, formData);
      }
      navigate('/keys');
    } catch (err) {
      console.error('Error saving key:', err);
      setError('Помилка при збереженні ключа.');
    } finally {
      setLoading(false);
    }
  };
  
  return (
    <Container>
      <h1>{isEditMode ? t('keyForm.editTitle') : t('keyForm.addTitle')}</h1>
      
      {error && <Alert variant="danger">{error}</Alert>}
      
      <Form onSubmit={handleSubmit}>
        <Form.Group className="mb-3">
          <Form.Label>{t('keyForm.fields.site')}</Form.Label>
          <Form.Select
            name="site_code"
            value={formData.site_code}
            onChange={handleChange}
            required
          >
            <option value="">{t('keyForm.fields.selectSite')}</option>
            {sites.map((site) => (
              <option key={site.site_id} value={site.site_code}>
                {site.site_code} - {site.address}
              </option>
            ))}
          </Form.Select>
        </Form.Group>
        
        <Form.Group className="mb-3">
          <Form.Label>{t('keyForm.fields.description')}</Form.Label>
          <Form.Control
            type="text"
            name="description"
            value={formData.description}
            onChange={handleChange}
            required
          />
        </Form.Group>
        
        <Form.Group className="mb-3">
          <Form.Label>{t('keyForm.fields.keyCount')}</Form.Label>
          <Form.Control
            type="number"
            name="key_count"
            min="1"
            value={formData.key_count}
            onChange={handleChange}
            required
          />
        </Form.Group>
        
        <Form.Group className="mb-3">
          <Form.Label>{t('keyForm.fields.setCount')}</Form.Label>
          <Form.Control
type="number"
            name="set_count"
            min="1"
            value={formData.set_count}
            onChange={handleChange}
            required
          />
        </Form.Group>
        
        <Form.Group className="mb-3">
          <Form.Label>{t('keyForm.fields.notes')}</Form.Label>
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
            {loading ? t('keyForm.buttons.saving') : t('keyForm.buttons.save')}
          </Button>
          
          <Button
            variant="secondary"
            onClick={() => navigate('/keys')}
          >
            {t('keyForm.buttons.cancel')}
          </Button>
        </div>
      </Form>
    </Container>
  );
};

export default KeyForm;

