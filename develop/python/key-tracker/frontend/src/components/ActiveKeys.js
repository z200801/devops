import React, { useState, useEffect } from 'react';
import { Container, Table, Button, Alert, Form, InputGroup } from 'react-bootstrap';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import axios from 'axios';
import { formatDateTime } from '../utils/dateFormatter';

const API_URL = '/api';

const ActiveKeys = () => {
  const { t } = useTranslation();
  const [activeKeys, setActiveKeys] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filterValue, setFilterValue] = useState('');
  const [isRegExp, setIsRegExp] = useState(false);
  
  useEffect(() => {
    fetchActiveKeys();
  }, []);
  
  const fetchActiveKeys = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API_URL}/active-keys/`);
      setActiveKeys(response.data);
      setError(null);
    } catch (err) {
      console.error('Error fetching active keys:', err);
      setError(t('issuedKeys.errorFetching'));
    } finally {
      setLoading(false);
    }
  };
  
  const handleFilterChange = (e) => {
    setFilterValue(e.target.value);
  };
  
  const toggleRegExp = () => {
    setIsRegExp(!isRegExp);
  };
  
  // Функція фільтрації даних
  const getFilteredKeys = () => {
    if (!filterValue.trim()) return activeKeys;
    
    try {
      if (isRegExp) {
        const regex = new RegExp(filterValue, 'i');
        return activeKeys.filter(key => 
          regex.test(key.site_code) || 
          regex.test(key.key_description) ||
          regex.test(key.issued_to || '')
        );
      } else {
        const lowercaseFilter = filterValue.toLowerCase();
        return activeKeys.filter(key => 
          key.site_code.toLowerCase().includes(lowercaseFilter) || 
          key.key_description.toLowerCase().includes(lowercaseFilter) ||
          (key.issued_to && key.issued_to.toLowerCase().includes(lowercaseFilter))
        );
      }
    } catch (err) {
      console.error('Error filtering keys:', err);
      return activeKeys;
    }
  };
  
  const filteredKeys = getFilteredKeys();
  
  return (
    <Container>
      <div className="d-flex justify-content-between align-items-center mb-4">
        <h1>{t('issuedKeys.title')}</h1>
        <div>
          <Link to="/keys/issue" className="btn btn-success me-2">
            {t('issuedKeys.issueKey')}
          </Link>
          <Link to="/keys/return" className="btn btn-warning">
            {t('issuedKeys.returnKey')}
          </Link>
        </div>
      </div>
      
      <Form.Group className="mb-3">
        <InputGroup>
          <Form.Control
            type="text"
            placeholder={t('issuedKeys.filter')}
            value={filterValue}
            onChange={handleFilterChange}
          />
          <InputGroup.Checkbox 
            label="RegExp"
            checked={isRegExp}
            onChange={toggleRegExp}
          />
          <InputGroup.Text>RegExp</InputGroup.Text>
        </InputGroup>
        <Form.Text className="text-muted">
          {isRegExp ? t('issuedKeys.filterMode.regexp') : t('issuedKeys.filterMode.simple')}
        </Form.Text>
      </Form.Group>
      
      {error && <Alert variant="danger">{error}</Alert>}
      
      {loading ? (
        <p>{t('issuedKeys.loading')}</p>
      ) : filteredKeys.length === 0 ? (
        <Alert variant="info">{t('issuedKeys.noKeys')}</Alert>
      ) : (
        <Table striped bordered hover responsive>
          <thead>
            <tr>
              <th>{t('issuedKeys.columns.site')}</th>
              <th>{t('issuedKeys.columns.description')}</th>
              <th>{t('issuedKeys.columns.issuedTo')}</th>
              <th>{t('issuedKeys.columns.issuedAt')}</th>
              <th>{t('issuedKeys.columns.actions')}</th>
            </tr>
          </thead>
          <tbody>
            {filteredKeys.map((key, index) => (
              <tr key={index}>
                <td>{key.site_code}</td>
                <td>{key.key_description}</td>
                <td>{key.issued_to}</td>
                <td>{formatDateTime(key.issued_at)}</td>
                <td>
                  <Link 
                    to={`/keys/return?siteCode=${key.site_code}`} 
                    className="btn btn-sm btn-warning"
                  >
                    {t('issuedKeys.actions.return')}
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </Table>
      )}
    </Container>
  );
};

export default ActiveKeys;

